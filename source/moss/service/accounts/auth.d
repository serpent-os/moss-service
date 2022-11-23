/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.accounts.auth
 *
 * Authentication helper for AccountManager
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.accounts.auth;

import vibe.d;

public import vibe.web.auth;
import moss.service.accounts.manager;
import moss.service.models.account;
import moss.service.tokens;
import moss.service.tokens.manager;
import std.string : split, strip;
import std.typecons : Nullable;

private enum AccessMode
{
    None = 0,
    BearerToken = 1 << 1,
    AccessToken = 1 << 2,
    WebConnection = 1 << 3,
    APIConnection = 1 << 4,
    Expired = 1 << 5,
    Admin = 1 << 6,
}

/**
 * Returns: the associated token for the incoming connection if one exists.
 *
 * Note: This is adapted for use with the `@before` decorator to stash a token
 * in a REST API function parameter.
 *
 * Params:
 *      request = Incoming request
 *      response = Outgoing response
 */
public NullableToken retrieveToken(scope return HTTPServerRequest request,
        scope return HTTPServerResponse response) @safe
{
    Token lookup = () @trusted {
        return request.context.get!Token("token", Token.init);
    }();
    return NullableToken(lookup);
}

/**
 * Attempt to determine authentication from the current web context
 */
public struct AccountAuthentication
{
    /**
     * Construct a AccountAuthentication helper from the given
     * HTTP connection.
     */
    this(scope return AccountManager accountManager, scope return TokenManager tokenManager,
            scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
    {
        string encodedToken;

        /* Try headers first */
        string authHeader = req.headers.get("Authorization", null);
        if (authHeader !is null)
        {
            auto tokens = authHeader.split();
            enforceHTTP(tokens.length == 2, HTTPStatus.badRequest,
                    "Invalid bearer token assignment");
            immutable method = tokens[0].strip();
            immutable payload = tokens[1].strip();

            enforceHTTP(method == "Bearer", HTTPStatus.forbidden,
                    "Only Bearer scheme supported for auth");
            encodedToken = payload;
            mode = AccessMode.APIConnection;
        }
        else if (req.session)
        {
            encodedToken = req.session.get!string("accessToken", null);
            mode = AccessMode.WebConnection;
        }

        /* MUST have a token by now .. */
        enforceHTTP(encodedToken !is null, HTTPStatus.forbidden, "You must supply a valid token");

        /* Decode what we found */
        Token.decode(encodedToken).match!((Token tk) { connectionToken = tk; }, (TokenError e) {
            throw new HTTPStatusException(HTTPStatus.forbidden, e.message);
        });

        /* Now verify that *we created it* */
        enforceHTTP(tokenManager.verifyOurs(connectionToken),
                HTTPStatus.forbidden, "Supplied token is not valid for this instance");

        accountType = connectionToken.payload.act;

        /* Establish admin permissions */
        if (connectionToken.payload.admin)
        {
            mode |= AccessMode.Admin;
        }

        /* Set the purpose */
        switch (connectionToken.payload.purpose)
        {
        case TokenPurpose.Authorization:
            mode |= AccessMode.BearerToken;
            break;
        case TokenPurpose.Authentication:
            mode |= AccessMode.AccessToken;
            break;
        default:
            throw new HTTPStatusException(HTTPStatus.badRequest, "Invalid token purpose");
        }

        /* Ensure timing is good */
        immutable timeNow = Clock.currTime(UTC()).toUnixTime();
        if (timeNow >= connectionToken.payload.exp)
        {
            mode |= AccessMode.Expired;
        }

        /* Stash the connection token */
        () @trusted { req.context["token"] = connectionToken; }();
    }

    /**
     * Returns: true if a bearer token is being used
     */
    pragma(inline, true) pure @property bool isBearerToken() @safe @nogc nothrow const
    {
        return (mode & AccessMode.BearerToken) == AccessMode.BearerToken;
    }

    /**
     * Returns: true if an access token is being used
     */
    pragma(inline, true) pure @property bool isAccessToken() @safe @nogc nothrow const
    {
        return (mode & AccessMode.AccessToken) == AccessMode.AccessToken;
    }

    /**
     * Returns: true if a web connection is being used
     */
    pragma(inline, true) pure @property bool isWeb() @safe @nogc nothrow const
    {
        return (mode & AccessMode.WebConnection) == AccessMode.WebConnection;
    }

    /**
     * Returns: true if an API connection (REST) is being used
     */
    pragma(inline, true) pure @property bool isAPI() @safe @nogc nothrow const
    {
        return (mode & AccessMode.APIConnection) == AccessMode.APIConnection;
    }

    /**
     * Returns: true if the token is for a service account
     */
    pragma(inline, true) pure @property bool isServiceAccount() @safe @nogc nothrow const
    {
        return accountType == AccountType.Service;
    }

    /**
     * Returns: true if the token is for a user account
     */
    pragma(inline, true) pure @property bool isUserAccount() @safe @nogc nothrow const
    {
        return accountType == AccountType.Standard;
    }

    /**
     * Returns: true if the token is for a bot account
     */
    pragma(inline, true) pure @property bool isBotAccount() @safe @nogc nothrow const
    {
        return accountType == AccountType.Bot;
    }

    /**
     * Returns: true if the token is expired
     */
    pragma(inline, true) pure @property bool isExpired() @safe @nogc nothrow const
    {
        return (mode & AccessMode.Expired) == AccessMode.Expired;
    }

    /**
     * Returns: true if the token is NOT expired
     */
    pragma(inline, true) pure @property bool isNotExpired() @safe @nogc nothrow const
    {
        return !isExpired();
    }

    /**
     * Returns: true if this token is for an admin
     */
    pragma(inline, true) pure @property bool isAdmin() @safe @nogc nothrow const
    {
        return (mode & AccessMode.Admin) == AccessMode.Admin;
    }

private:

    AccessMode mode = AccessMode.None;
    AccountType accountType = AccountType.Bot;
    Token connectionToken;
}

/**
 * Generate boilerplate needed to get authentication working
 *
 * You will need an accountManager and tokenManager instance available.
 */
mixin template AppAuthenticator()
{
    @noRoute public AccountAuthentication authenticate(scope HTTPServerRequest req,
            scope HTTPServerResponse res) @safe
    {
        return AccountAuthentication(accountManager, tokenManager, req, res);
    }
}

/**
 * Similar to the AppAuthenticator mixin, relies instead on a context variable
 */
mixin template AppAuthenticatorContext()
{
    @noRoute public AccountAuthentication authenticate(scope HTTPServerRequest req,
            scope HTTPServerResponse res) @safe
    {
        return AccountAuthentication(context.accountManager, context.tokenManager, req, res);
    }
}
