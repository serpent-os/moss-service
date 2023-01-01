/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.accounts.manager
 *
 * Account management
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.accounts.manager;

public import moss.db.keyvalue.errors;
public import moss.service.models.account;
public import moss.service.models.credential;
public import std.sumtype;
import libsodium;
import moss.db.keyvalue;
import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.orm;
import moss.service.accounts : serviceAccountPrefix;
import moss.service.models.bearertoken;
import moss.service.models.group;
import std.algorithm : canFind, filter, sort, uniq;
import std.array : array;
import std.string : format;
import vibe.d;

/**
 * AccountManager has some built in groups to make life
 * easier from a simplistic permission model PoV
 */
public static enum BuiltinGroups : string
{
    /**
     * Special case administrative user group
     */
    Admin = "admin",

    /**
     * Standard user group
     */
    Users = "users"
}

/**
 * Baked in groups
 */
private static immutable requiredGroups = [
    Group(0, BuiltinGroups.Users, "Standard users"),
    Group(0, BuiltinGroups.Admin, "Administrators"),
];

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
        accountDB = Database.open(format!"lmdb://%s"(dbPath),
                DatabaseFlags.CreateIfNotExists).tryMatch!((Database db) => db);

        /* Ensure model exists */
        auto err = accountDB.update((scope tx) => tx.createModel!(Credential,
                Account, Group, BearerToken));
        enforceHTTP(err.isNull, HTTPStatus.internalServerError, err.message);

        /* Now we need some *internal* groups for things to function correctly. */
        static foreach (group; requiredGroups)
        {
            {
                getGroup(group.slug).match!((Group g) {
                    logDiagnostic(format!"requiredGroup exists: %s"(group.slug));
                }, (DatabaseError err) {
                    enforceHTTP(err.code != DatabaseErrorCode.BucketNotFound,
                        HTTPStatus.internalServerError, "Failed to integrate requiredGroups");
                    createGroup(group).match!((Group g) {
                        logInfo(format!"Created requiredGroup: %s"(group.slug));
                    }, (DatabaseError err) {
                        throw new HTTPStatusException(HTTPStatus.internalServerError, err.message);
                    });
                });
            }
        }
    }

    /**
     * Close underlying resources
     */
    void close() @safe
    {
        if (accountDB is null)
        {
            return;
        }
        accountDB.close();
        accountDB = null;
    }

    /**
     * Attempt to register the user.
     *
     * Params:
     *      username = New user identifier
     *      password = New password
     * Returns: New account or an error
     */
    SumType!(Account, DatabaseError) registerUser(string username, string password, string email) @safe
    {
        /* Prevent use of a service identity */
        if (username.startsWith(serviceAccountPrefix))
        {
            return SumType!(Account, DatabaseError)(DatabaseError(DatabaseErrorCode.BucketExists,
                    "Users may not register service prefix accounts"));
        }

        /* Make sure nobody exists with that username. */
        {
            Account lookupAccount;
            immutable err = accountDB.view((in tx) => lookupAccount.load!"username"(tx, username));
            if (err.isNull)
            {
                return SumType!(Account, DatabaseError)(DatabaseError(DatabaseErrorCode.BucketExists,
                        "That username isn't unavailable right now"));
            }
        }

        /* Register the new user */
        auto user = Account();
        auto cred = Credential();
        cred.hashedPassword = generateSodiumHash(password);
        user.username = username;
        user.type = AccountType.Standard;
        user.email = email;

        /* Helper to incorporate a user */
        DatabaseResult incorporateUser(scope Transaction tx) @safe
        {
            immutable errUser = user.save(tx);
            if (!errUser.isNull)
            {
                return errUser;
            }
            /* Update user id now */
            cred.id = user.id;
            return cred.save(tx);
        }

        immutable err = accountDB.update(&incorporateUser);
        return err.isNull ? SumType!(Account,
                DatabaseError)(user) : SumType!(Account, DatabaseError)(err);
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
    SumType!(Account, DatabaseError) authenticateUser(string username, string password) @safe
    {
        Account lookup;
        static auto noAccount = DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                "Username or password incorrect"));

        immutable err = accountDB.view((in tx) @safe {
            /* Check if the user exists first :) */
            immutable err = lookup.load!"username"(tx, username);
            if (!err.isNull)
            {
                return noAccount;
            }
            /* Disallow non-standard authentication */
            if (lookup.type != AccountType.Standard)
            {
                return noAccount;
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
                return noAccount;
            }
            return NoDatabaseError;
        });
        /* You can haz Account now */
        if (err.isNull)
        {
            return SumType!(Account, DatabaseError)(lookup);
        }
        return SumType!(Account, DatabaseError)(err);
    }

    /**
     * Register a service account
     *
     * Params:
     *      username = Service username
     *      email = Potential contact point
     * Returns: Nullable database error
     */
    SumType!(Account, DatabaseError) registerService(string username, string email) @safe
    {
        /* Enforce use of a service identity */
        if (!username.startsWith(serviceAccountPrefix))
        {
            return SumType!(Account, DatabaseError)(DatabaseError(DatabaseErrorCode.BucketExists,
                    "Services must register service prefixed accounts"));
        }

        /* Make sure nobody exists with that username. */
        {
            Account lookupAccount;
            immutable err = accountDB.view((in tx) => lookupAccount.load!"username"(tx, username));
            if (err.isNull)
            {
                return SumType!(Account, DatabaseError)(DatabaseError(DatabaseErrorCode.BucketExists,
                        "Service identity already taken"));
            }
        }

        /* Register the new user */
        auto user = Account();
        user.username = username;
        user.type = AccountType.Service;
        user.email = email;
        immutable err = accountDB.update((scope tx) => user.save(tx));
        return err.isNull ? SumType!(Account,
                DatabaseError)(user) : SumType!(Account, DatabaseError)(err);
    }

    /**
     * Update the bearer token associated with the user
     *
     * Params:
     *     user = User account
     *     token = New bearer token
     * Returns: Nullable database error
     */
    DatabaseResult setBearerToken(in Account user, BearerToken token) @safe
    {
        token.id = user.id;

        /* Account MUST exist */
        Account lookup;
        immutable err = accountDB.view((in tx) => lookup.load(tx, user.id));
        if (!err.isNull)
        {
            return err;
        }

        return accountDB.update((scope tx) => token.save(tx));
    }

    /**
     * Grab a group
     *
     * Params:
     *      groupName = Specific group name
     * Returns: Group on success, DatabasError on failure
     */
    SumType!(Group, DatabaseError) getGroup(string groupName) @safe
    {
        Group lookup;
        immutable err = accountDB.view((in tx) => lookup.load!"slug"(tx, groupName));
        return err.isNull ? SumType!(Group,
                DatabaseError)(lookup) : SumType!(Group, DatabaseError)(err);
    }

    /**
     * Construct a new group.
     *
     * Params:
     *      group = Template for the new group
     * Returns: A populated Group on success, or a DatabaseError
     */
    SumType!(Group, DatabaseError) createGroup(Group group) @safe
    {
        /* Ensure we can store this in the DB.. */
        group.id = 0;
        group.members = null;

        group.name = group.name.strip();
        group.slug = group.slug.strip();
        if (group.name.empty)
        {
            return SumType!(Group, DatabaseError)(DatabaseError(DatabaseErrorCode.UncaughtException,
                    "Group name empty"));
        }
        if (group.slug.empty)
        {
            return SumType!(Group, DatabaseError)(DatabaseError(DatabaseErrorCode.UncaughtException,
                    "Group slug empty"));
        }
        {
            Group lookup;
            immutable err = accountDB.view((in tx) => lookup.load!"slug"(tx, group.slug));
            if (err.isNull)
            {
                return SumType!(Group, DatabaseError)(DatabaseError(DatabaseErrorCode.BucketExists,
                        "Group already exists with that slug"));
            }
        }

        immutable err = accountDB.update((scope tx) => group.save(tx));
        return err.isNull ? SumType!(Group,
                DatabaseError)(group) : SumType!(Group, DatabaseError)(err);
    }

    /**
     * Returns: true if the given account is in the specified group
     * Params:
     *      accountID = Unique account identifier
     *      groupName = Unique group name
     */
    SumType!(bool, DatabaseError) accountInGroup(in AccountIdentifier accountID, string groupName) @safe
    {
        Group lookup;
        Account account;

        /* Firstly, make sure the group even exists.. */
        {
            immutable err = accountDB.view((in tx) => lookup.load!"slug"(tx, groupName));
            if (!err.isNull)
            {
                return SumType!(bool, DatabaseError)(err);
            }
        }

        /* Make sure we can find the user */
        immutable err = accountDB.view((in tx) => account.load(tx, accountID));
        if (!err.isNull)
        {
            return SumType!(bool, DatabaseError)(err);
        }

        /* Now ensure we can find it */
        return SumType!(bool, DatabaseError)(account.groups.canFind!((el) => el == lookup.id));
    }

    /**
     * Add an account to the given groups
     *
     * Params:
     *      accountID = Unique account identifier
     *      groups = Group names to add to
     * Returns: An error if one occurred
     */
    DatabaseResult addAccountToGroups(in AccountIdentifier accountID, string[] groups) @safe
    {
        DatabaseResult accountToGroupTx(scope Transaction tx, string group) @safe
        {
            Group lookup;
            Account account;

            immutable groupErr = lookup.load!"slug"(tx, group);
            if (!groupErr.isNull)
            {
                return groupErr;
            }
            immutable accountErr = account.load(tx, accountID);
            if (!accountErr.isNull)
            {
                return accountErr;
            }

            /* Set the accountID in group + user membership */
            lookup.members ~= accountID;
            lookup.members.sort;
            lookup.members = () @trusted { return lookup.members.uniq.array; }();

            /* Likewise do the same for the account group membership */
            account.groups ~= lookup.id;
            account.groups.sort;
            account.groups = () @trusted { return account.groups.uniq.array; }();

            /* Now store account */
            immutable gstErr = lookup.save(tx);
            if (!gstErr.isNull)
            {
                return gstErr;
            }
            immutable actErr = account.save(tx);
            if (!actErr.isNull)
            {
                return actErr;
            }
            return NoDatabaseError;
        }

        foreach (group; groups)
        {
            immutable err = accountDB.update((scope tx) => accountToGroupTx(tx, group));
            if (!err.isNull)
            {
                return err;
            }
        }

        return NoDatabaseError;
    }

    /**
     * Remove an account from the given groups
     *
     * Params:
     *      accountID = Unique account identifier
     *      groups = Group names to remove the account from
     * Returns: An error if one occurred
     */
    DatabaseResult removeAccountFromGroups(in AccountIdentifier accountID, string[] groups) @safe
    {
        DatabaseResult accountToGroupTx(scope Transaction tx, string group) @safe
        {
            Group lookup;
            Account account;

            immutable groupErr = lookup.load!"slug"(tx, group);
            if (!groupErr.isNull)
            {
                return groupErr;
            }
            immutable accountErr = account.load(tx, accountID);
            if (!accountErr.isNull)
            {
                return accountErr;
            }

            /* Remove the accountID in group + user membership */
            lookup.members.sort;
            lookup.members = () @trusted {
                return lookup.members.uniq.filter!((el) => el == accountID).array;
            }();

            /* Likewise do the same for the account group membership */
            account.groups ~= lookup.id;
            account.groups.sort;
            account.groups = () @trusted {
                return account.groups.uniq.filter!((el) => el == lookup.id).array;
            }();

            /* Now store account */
            immutable gstErr = lookup.save(tx);
            if (!gstErr.isNull)
            {
                return gstErr;
            }
            immutable actErr = account.save(tx);
            if (!actErr.isNull)
            {
                return actErr;
            }
            return NoDatabaseError;
        }

        foreach (group; groups)
        {
            immutable err = accountDB.update((scope tx) => accountToGroupTx(tx, group));
            if (!err.isNull)
            {
                return err;
            }
        }

        return NoDatabaseError;
    }

private:

    Database accountDB;
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
