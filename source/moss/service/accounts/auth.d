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

import moss.service.accounts.manager;
import moss.service.tokens;
import moss.service.tokens.manager;
import moss.service.models.account;

private enum AccessMode
{
    None = 0,
    BearerToken = 1 << 1,
    AccessToken = 1 << 2,
    WebConnection = 1 << 3,
    APIConnection = 1 << 4
};

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
        throw new HTTPStatusException(HTTPStatus.forbidden, "no permissions implemented sorry");
    }

    /**
     * Returns: true if a bearer token is being used
     */
    pure @property bool isBearerToken() @safe @nogc nothrow const
    {
        return (mode & AccessMode.BearerToken) == AccessMode.BearerToken;
    }

    /**
     * Returns: true if an access token is being used
     */
    pure @property bool isAccessToken() @safe @nogc nothrow const
    {
        return (mode & AccessMode.AccessToken) == AccessMode.AccessToken;
    }

    /**
     * Returns: true if a web connection is being used
     */
    pure @property bool isWeb() @safe @nogc nothrow const
    {
        return (mode & AccessMode.WebConnection) == AccessMode.WebConnection;
    }

    /**
     * Returns: true if an API connection (REST) is being used
     */
    pure @property bool isAPI() @safe @nogc nothrow const
    {
        return (mode & AccessMode.APIConnection) == AccessMode.APIConnection;
    }

    /**
     * Returns: true if the token is for a service account
     */
    pure @property bool isServiceAccount() @safe @nogc nothrow const
    {
        return accountType == AccountType.Service;
    }

    /**
     * Returns: true if the token is for a user account
     */
    pure @property bool isUserAccount() @safe @nogc nothrow const
    {
        return accountType == AccountType.Standard;
    }

    /**
     * Returns: true if the token is for a bot account
     */
    pure @property bool isBotAccount() @safe @nogc nothrow const
    {
        return accountType == AccountType.Bot;
    }

private:

    AccessMode mode = AccessMode.None;
    AccountType accountType = AccountType.Bot;
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
