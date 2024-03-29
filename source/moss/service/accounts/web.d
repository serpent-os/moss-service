/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.accounts.web
 *
 * Account authentication
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.accounts.web;

import vibe.d;
import vibe.web.validation;
import moss.service.accounts.manager;
import moss.service.tokens;
import moss.service.tokens.manager;

/**
 * The AccountsWeb expects to live on the `/accounts`
 * route within the application. You should extend this
 * implementation to render the following paths:
 *
 *  GET /login
 *  GET /register
 */
@path("/accounts") public abstract class AccountsWeb
{
    @disable this();

    /**
     * Construct new AccountsWeb
     *
     * Params:
     *      accountManager = Account management
     *      tokenManager = Token management
     */
    this(AccountManager accountManager, TokenManager tokenManager, string issuer) @safe
    {
        this.accountManager = accountManager;
        this.tokenManager = tokenManager;
        this.issuer = issuer;
    }

    @path("login") @method(HTTPMethod.GET) abstract void renderLogin() @safe;
    @path("register") @method(HTTPMethod.GET) abstract void renderRegister() @safe;

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
            startSession(user);
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
     * Throws: HTTPStatusException if registration is forbidden
     */
    final @method(HTTPMethod.POST) @path("register") void handleRegistration(ValidUsername username,
            ValidEmail emailAddress, ValidPassword password,
            Confirm!"password" confirmPassword, bool policy) @safe
    {
        enforceHTTP(accountManager.userRegistrationsAllowed,
                HTTPStatus.forbidden, "User registration not permitted");
        scope (exit)
        {
            redirect("/");
        }
        scope (failure)
        {
            endSession();
        }
        enforceHTTP(policy, HTTPStatus.forbidden, "Policy must be accepted");
        accountManager.registerUser(username, password, emailAddress).match!((Account act) {
            startSession(act);
        }, (DatabaseError err) {
            endSession();
            throw new HTTPStatusException(HTTPStatus.forbidden, err.message);
        });
    }

private:

    /**
     * Start a login session
     *
     * Params:
     *      account = Account to start a session with
     * Throws: HTTPStatusException if token construction fails
     */
    void startSession(Account account) @safe
    {
        TokenPayload payload;
        payload.uid = account.id;
        payload.act = account.type;
        payload.sub = account.username;
        /* aud is always web-user, whereas issuer is set on per impl. basis */
        payload.aud = "web-user";
        payload.iss = this.issuer;
        payload.purpose = TokenPurpose.Authentication;
        payload.admin = accountManager.accountInGroup(account.id,
                BuiltinGroups.Admin).tryMatch!((bool b) => b);
        Token tk = tokenManager.createAPIToken(payload);
        tokenManager.signToken(tk).match!((string encoded) {
            Session sess = request.session ? request.session : response.startSession();
            sess.set("accessToken", encoded);
            sess.set("accountID", account.id);
            sess.set("accountName", account.username);
            sess.set("accountAdmin", payload.admin);
        }, (TokenError error) {
            throw new HTTPStatusException(HTTPStatus.internalServerError, error.message);
        });
    }

    /**
     * End the session
     */
    void endSession() @safe
    {
        if (request.session)
        {
            terminateSession();
        }
    }

    string issuer;
    AccountManager accountManager;
    TokenManager tokenManager;
}
