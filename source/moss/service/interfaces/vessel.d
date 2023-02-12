/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.interfaces.vessel
 *
 * Public API for Vessel <-> Summit negotiation
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.interfaces.vessel;

public import std.stdint : uint64_t;

public import moss.service.interfaces : Collectable, CollectableType;
public import moss.service.tokens : NullableToken;
import moss.service.accounts.auth : retrieveToken;
import vibe.d;
import vibe.web.auth;

/**
 * The Vessel API
 */
@requiresAuth @path("/api/v1/vessel") public interface VesselAPI
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
     * Assuming all authentication parameters are met, begin an import for all .Package
     * assets provided in the API call to import them into the volatile repository.
     *
     * Upon completion, an appropriate summit API callback will be invoked to report the
     * success or failure of the call.
     *
     * Params:
     *   taskID = Summit's internal taskID
     *   collectables = Should only contain .Package artefacts for inclusion
     *   token = set by middleware
     */
    @before!retrieveToken("token") @path("build") @method(HTTPMethod.POST)
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.accessToken)
    void importBinaries(uint64_t taskID, Collectable[] collectables, NullableToken token) @safe;
}
