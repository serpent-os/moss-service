/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.acounts
 *
 * Account management
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.accounts;

public import moss.db.keyvalue.errors;
public import moss.service.models.credential;
public import moss.service.models.user;
public import std.sumtype;
import libsodium;
import moss.db.keyvalue;
import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.orm;
import moss.service.models.bearertoken;
import moss.service.models.group;
import std.string : format;
import vibe.d;

/**
 * All service accounts are prefixed with svc- and cannot be used
 * by normal users.
 */
public static immutable string serviceAccountPrefix = "@";

/**
 * Attempt to determine authentication from the current web context
 *
 * Note this is not the same thing as authorisation, that is handled
 * by tokens and permissions.
 */
public struct ServiceAuthentication
{
    /**
     * Construct a ServiceAuthentication helper from the given
     * HTTP connection
     * To make use of this, simply construct and return the type from
     * your APIs authenticate(req, res) method and it will do the rest.
     */
    this(scope return AccountManager accountManager, scope HTTPServerRequest req,
            scope HTTPServerResponse res) @safe
    {
        throw new HTTPStatusException(HTTPStatus.forbidden, "no permissions implemented sorry");
    }

    /**
     * Remote access tokens - sessions are invalid.
     *
     * Returns: true if using a remote access token
     */
    pure bool isRemoteAccess() @safe @nogc nothrow
    {
        return false;
    }
}

/**
 * Generate boilerplate needed to get authentication working
 *
 * You will need an accountManager instance available.
 */
mixin template AppAuthenticator()
{
    @noRoute public ServiceAuthentication authenticate(scope HTTPServerRequest req,
            scope HTTPServerResponse res) @safe
    {
        return ServiceAuthentication(accountManager, req, res);
    }
}

/**
 * The AccountManager hosts all account management within
 * its own DB tree.
 */
public final class AccountManager
{
    @disable this();

    /**
     * Construct a new AccountManager from the given path
     */
    this(string dbPath) @safe
    {
        /* Enforce the creation */
        userDB = Database.open(format!"lmdb://%s"(dbPath),
                DatabaseFlags.CreateIfNotExists).tryMatch!((Database db) => db);

        /* Ensure model exists */
        auto err = userDB.update((scope tx) => tx.createModel!(Credential, User,
                Group, BearerToken));
        enforceHTTP(err.isNull, HTTPStatus.internalServerError, err.message);
    }

    /**
     * Close underlying resources
     */
    void close() @safe
    {
        if (userDB is null)
        {
            return;
        }
        userDB.close();
        userDB = null;
    }

    /**
     * Attempt to register the user.
     *
     * Params:
     *      username = New user identifier
     *      password = New password
     * Returns: Nullable database error
     */
    DatabaseResult registerUser(string username, string password, string email) @safe
    {
        /* Prevent use of a service identity */
        if (username.startsWith(serviceAccountPrefix))
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketExists,
                    "Users may not register service prefix accounts"));
        }

        /* Make sure nobody exists with that username. */
        {
            User lookupUser;
            immutable err = userDB.view((in tx) => lookupUser.load!"username"(tx, username));
            if (err.isNull)
            {
                return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketExists,
                        "That username isn't unavailable right now"));
            }
        }

        /* Register the new user */
        auto user = User();
        auto cred = Credential();
        cred.hashedPassword = generateSodiumHash(password);
        user.username = username;
        user.type = UserType.Standard;
        user.email = email;
        immutable userErr = userDB.update((scope tx) => user.save(tx));
        if (!userErr.isNull)
        {
            return userErr;
        }
        return userDB.update((scope tx) => cred.save(tx));
    }

    /**
     * Check if authentication works via the DB
     *
     * To prevent brute force we'll never admit if a username exists.
     *
     * Params:
     *      username = Registered username
     *      password = Registered password
     * Returns: Nullable database error
     */
    SumType!(User, DatabaseError) authenticateUser(string username, string password) @safe
    {
        User lookup;
        static auto noUser = DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                "Username or password incorrect"));

        immutable err = userDB.view((in tx) @safe {
            /* Check if the user exists first :) */
            immutable err = lookup.load!"username"(tx, username);
            if (!err.isNull)
            {
                return noUser;
            }
            /* Disallow non-standard authentication */
            if (lookup.type != UserType.Standard)
            {
                return noUser;
            }
            /* Check credential storage */
            Credential cred;
            immutable credErr = cred.load(tx, lookup.id);
            if (!credErr.isNull)
            {
                return credErr;
            }
            /* Check the password is right */
            if (!sodiumHashMatch(cred.hashedPassword, password))
            {
                return noUser;
            }
            return NoDatabaseError;
        });
        /* You can haz User now */
        if (err.isNull)
        {
            return SumType!(User, DatabaseError)(lookup);
        }
        return SumType!(User, DatabaseError)(err);
    }

    /**
     * Register a service account
     *
     * Params:
     *      username = Service username
     *      email = Potential contact point
     * Returns: Nullable database error
     */
    SumType!(User, DatabaseError) registerService(string username, string email) @safe
    {
        /* Enforce use of a service identity */
        if (!username.startsWith(serviceAccountPrefix))
        {
            return SumType!(User, DatabaseError)(DatabaseError(DatabaseErrorCode.BucketExists,
                    "Services must register service prefixed accounts"));
        }

        /* Make sure nobody exists with that username. */
        {
            User lookupUser;
            immutable err = userDB.view((in tx) => lookupUser.load!"username"(tx, username));
            if (err.isNull)
            {
                return SumType!(User, DatabaseError)(DatabaseError(DatabaseErrorCode.BucketExists,
                        "Service identity already taken"));
            }
        }

        /* Register the new user */
        auto user = User();
        user.username = username;
        user.type = UserType.Service;
        user.email = email;
        immutable err = userDB.update((scope tx) => user.save(tx));
        return err.isNull ? SumType!(User,
                DatabaseError)(user) : SumType!(User, DatabaseError)(err);
    }

    /**
     * Update the bearer token associated with the user
     *
     * Params:
     *     user = User account
     *     token = New bearer token
     * Returns: Nullable database error
     */
    DatabaseResult setBearerToken(in User user, BearerToken token) @safe
    {
        token.id = user.id;

        /* User MUST exist */
        User lookup;
        immutable err = userDB.view((in tx) => lookup.load(tx, user.id));
        if (!err.isNull)
        {
            return err;
        }

        return userDB.update((scope tx) => token.save(tx));
    }

private:

    Database userDB;
}

/**
 * Generate sodium hash from input
 */
static private string generateSodiumHash(in string password) @safe
{
    char[crypto_pwhash_STRBYTES] ret;
    auto inpBuffer = password.toStringz;
    int rc = () @trusted {
        return crypto_pwhash_str(ret, cast(char*) inpBuffer, password.length,
                crypto_pwhash_OPSLIMIT_INTERACTIVE, crypto_pwhash_MEMLIMIT_INTERACTIVE);
    }();

    if (rc != 0)
    {
        return null;
    }
    return ret.fromStringz.dup;
}

/**
 * Verify a password matches the given stored hash
 */
static private bool sodiumHashMatch(in string hash, in string userPassword) @safe
in
{
    assert(hash.length <= crypto_pwhash_STRBYTES);
}
do
{
    return () @trusted {
        char[crypto_pwhash_STRBYTES] buf;
        auto pwPtr = hash.toStringz;
        auto userPtr = userPassword.toStringz;
        buf[0 .. hash.length + 1] = pwPtr[0 .. hash.length + 1];

        return crypto_pwhash_str_verify(buf, userPtr, userPassword.length);
    }() == 0;
}

/**
 * Lock a region of memory
 *
 * Params:
 *      inp = Region of memory to lock
 */
public static void lockString(ref string inp) @safe
{
    () @trusted {
        auto rc = sodium_mlock(cast(void*) inp.ptr, inp.length);
        enforceHTTP(rc == 0, HTTPStatus.internalServerError, "Failed to sodium_mlock string");
    }();
}

/**
 * Unlock and zero memory
 *
 * Params:
 *      inp = Region of memory to unlock
 */
public static void unlockString(ref string inp) @safe
{
    () @trusted {
        auto rc = sodium_munlock(cast(void*) inp.ptr, inp.length);
        enforceHTTP(rc == 0, HTTPStatus.internalServerError, "Failed to sodium_munlock string");
    }();
}
