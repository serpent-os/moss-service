/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.interfaces.summit
 *
 * Public API for Summit dashboard
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.interfaces.summit;

public import std.stdint : uint64_t;

public import moss.service.tokens : NullableToken;
public import moss.service.interfaces : Collectable;
import moss.service.accounts.auth : retrieveToken;
import vibe.d;
import vibe.web.auth;

/**
 * The public Summit API
 */
@requiresAuth @path("/api/v1/summit") public interface SummitAPI
{

    /**
     * Stub implementation for clients to build. Use `.requestFilter`
     *
     * Params:
     *      req = incoming request
     *      res = outgoing response
     */
    static void authenticate(HTTPServerRequest req, HTTPServerResponse res) @safe
    {
        throw new HTTPStatusException(HTTPStatus.notImplemented,
                ".authenticate() method should have been overriden!");
    }

    /** 
     * Inform the dashboard that the build failed
     *
     * Params:
     *   taskID = Unique task identifier
     *   collectables = Should include at least the log file
     *   token = Set by middleware
     */
    @before!retrieveToken("token") @path("buildFailed") @method(HTTPMethod.POST)
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.accessToken)
    void buildFailed(uint64_t taskID, Collectable[] collectables, NullableToken token) @safe;

    /** 
     * Inform the dashboard that the build succeeded
     *
     * Params:
     *   taskID = Unique task identifier
     *   collectables = Needs to include the log file, and all stones
     *   token = Set by middleware
     */
    @before!retrieveToken("token") @path("buildSucceeded") @method(HTTPMethod.POST)
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.accessToken)
    void buildSucceeded(uint64_t taskID, Collectable[] collectables, NullableToken token) @safe;

    /** 
     * Inform dashboard that importing packages for the task failed
     *
     * Params:
     *   taskID = Unique task identifier
     *   token = Set by middleware
     */
    @before!retrieveToken("token") @path("importFailed") @method(HTTPMethod.POST)
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.accessToken)
    void importFailed(uint64_t taskID, NullableToken token) @safe;

    /** 
     * Inform dashboard that importing packages for the task succeeded
     *
     * Params:
     *   taskID = Unique task identifier
     *   token = Set by middleware
     */
    @before!retrieveToken("token") @path("importSucceeded") @method(HTTPMethod.POST)
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.accessToken)
    void importSucceeded(uint64_t taskID, NullableToken token) @safe;
}
