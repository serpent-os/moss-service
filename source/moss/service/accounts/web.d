/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.accounts.web
 *
 * Account authentication
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.accounts.web;

import vibe.d;
import vibe.web.validation;
import moss.service.accounts.manager;
import moss.service.tokens.manager;

/**
 * The AccountsWeb expects to live on the `/accounts`
 * route within the application. You should extend this
 * implementation to render the following paths:
 *
 *  GET /login
 *  GET /register
 */
@path("accounts") public abstract class AccountsWeb
{
    @disable this();

    /**
     * Construct new AccountsWeb
     *
     * Params:
     *      accountManager = Account management
     *      tokenManager = Token management
     */
    this(AccountManager accountManager, TokenManager tokenManager) @safe
    {
        this.accountManager = accountManager;
        this.tokenManager = tokenManager;
    }

    @path("login") @method(HTTPMethod.GET) abstract void renderLogin() @safe;
    @path("register") @method(HTTPMethod.GET) abstract void renderRegister() @safe;

    /**
     * Install account management into web app
     *
     * Params:
     *      router = Root namespace
     */
    final @noRoute void configure(URLRouter router) @safe
    {
        router.registerWebInterface(this);
    }

    /**
     * Log the session out
     */
    final @method(HTTPMethod.GET) @path("logout") void logout() @safe
    {
        endSession();
        redirect("/");
    }

    /**
     * Perform the login
     *
     * Params:
     *      username = Valid username
     *      password = Valid password
     */
    final @method(HTTPMethod.POST) @path("login") void handleLogin(
            ValidUsername username, ValidPassword password) @safe
    {
        accountManager.authenticateUser(username, password).match!((Account user) {
            logInfo(format!"User successfully logged in: %s [%s]"(user.username, user.id));
            startSession();
        }, (DatabaseError e) {
            logError(format!"Failed login for user '%s': %s"(username, e));
            endSession();
            throw new HTTPStatusException(HTTPStatus.forbidden, e.message);
        });
        redirect("/");
    }

    /**
     * Register a new user
     *
     * Params:
     *      username = New username
     *      emailAddress = Valid email address
     *      password = New password
     *      confirmPassword = Validate password
     *      policy = Ensure policy is accepted
     */
    final @method(HTTPMethod.POST) @path("register") void handleRegistration(ValidUsername username,
            ValidEmail emailAddress, ValidPassword password,
            Confirm!"password" confirmPassword, bool policy) @safe
    {
        scope (exit)
        {
            redirect("/");
        }
        scope (failure)
        {
            endSession();
        }
        enforceHTTP(policy, HTTPStatus.forbidden, "Policy must be accepted");
        immutable err = accountManager.registerUser(username, password, emailAddress);
        enforceHTTP(err.isNull, HTTPStatus.forbidden, err.message);
        startSession();
    }

private:

    /**
     * Start a login session
     */
    void startSession() @safe
    {
        logError("startSession(): Not yet implemented");
    }

    /**
     * End the session
     */
    void endSession() @safe
    {
        logError("endSession(): Not yet implemented");
        terminateSession();
    }

    AccountManager accountManager;
    TokenManager tokenManager;
}
