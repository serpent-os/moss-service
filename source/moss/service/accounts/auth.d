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
import moss.service.tokens.manager;

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
