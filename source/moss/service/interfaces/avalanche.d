/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.interfaces.avalanche
 *
 * Public API for Avalanche <-> Summit negotiation
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.interfaces.avalanche;

public import std.stdint : uint64_t;

public import moss.service.tokens : NullableToken;
import moss.service.accounts.auth : retrieveToken;
import vibe.d;
import vibe.web.auth;

/**
 * Collections to add to the profile
 *
 * Collections are simply binary repositories.
 */
struct BinaryCollection
{
    /**
     * Where to find the index
     */
    string indexURI;

    /**
     * Name of the collection
     */
    string name;

    /**
     * Priority for the collection (default 0)
     */
    uint priority;
}

/**
 * JSON Object to describe the complete requirements to perform
 * a build.
 */
struct PackageBuild
{
    /**
     * Remote build identifier
     */
    uint64_t buildID;

    /**
     * Upstream git URI
     */
    string uri;

    /**
     * Some git ref to checkout
     */
    string commitRef;

    /**
     * Relative path to the source, i.e. base/moss/stone.yml
     */
    string relativePath;

    /** 
     * The build architecture. MUST match the boulder architecture
     */
    string buildArchitecture;

    /**
     * The collections to enable in this build
     * Default boulder profiles are ignored
     */
    BinaryCollection[] collections;
}

/**
 * The BuildAPI
 */
@requiresAuth @path("/api/v1/avalanche") public interface AvalancheAPI
{
    /**
     * Perform an authenticated build using the details specified in the
     * request payload.
     *
     * Must come from a fully paired Summit instance, using a non-expired
     * access token.
     *
     * It is imperative the buildID matches the internal taskID in summit
     * to permit a reporting system.
     *
     * This function will always return 200 on success, otherwise if the
     * build has been incorrectly scheduled an error will be thrown.
     */
    @before!retrieveToken("token") @path("build") @method(HTTPMethod.POST)
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.accessToken)
    void buildPackage(PackageBuild request, NullableToken token) @safe;
}
