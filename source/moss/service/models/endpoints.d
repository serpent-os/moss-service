/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.models.endpoints
 *
 * Group encapsulation
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.models.endpoints;

public import moss.db.keyvalue.orm;
public import moss.service.models.user : UserIdentifier;

/**
 * Persistence of a vessel endpoint
 */
public @Model struct VesselEndpoint
{
    /**
     * Unique identifier for the endpoint
     */
    @PrimaryKey string id;

    /**
     * Linked service account
     */
    UserIdentifier serviceAccount;
}

/**
 * Persistence of an avalanche endpoint
 */
public @Model struct AvalancheEndpoint
{
    /**
     * Unique identifier for the endpoint
     */
    @PrimaryKey string id;

    /**
     * Linked service account
     */
    UserIdentifier serviceAccount;
}

/**
 * Persistence of a summit endpoint
 */
public @Model struct SummitEndpoint
{
    /**
     * Unique identifier for the endpoint
     */
    @PrimaryKey string id;

    /**
     * Linked service account
     */
    UserIdentifier serviceAccount;
}
