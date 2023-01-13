/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.models.endpoints
 *
 * Group encapsulation
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.models.endpoints;

public import moss.db.keyvalue.orm;
public import moss.service.models.account : AccountIdentifier;

public import std.stdint : uint64_t;

public enum EndpointStatus
{
    /* i.e avalanche admin needs to accept summit pairing */
    AwaitingAcceptance = 0,

    /* Summit sent a request, awaiting enrol now */
    AwaitingEnrolment,

    /* Declined or failed. */
    Failed,

    /* Up and running */
    Operational,
}

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
     * Pairing status
     */
    EndpointStatus status;

    /**
     * Status display
     */
    string statusText;

    /**
     * Linked service account
     */
    AccountIdentifier serviceAccount;

    /**
     * Where is everything published?
     */
    string volatileIndexURI;
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
     * Where can we reach this endpoint?
     */
    string hostAddress;

    /**
     * Encoded public key
     */
    string publicKey;

    /**
     * Visual description for this endpoint's nature
     *
     * i.e. sponsored by <such and such>
     */
    string description;

    /**
     * Administrator email address (must be up to date)
     */
    string adminEmail;

    /**
     * Administrator's name
     */
    string adminName;

    /**
     * Status
     */
    EndpointStatus status;

    /**
     * Special display text
     */
    string statusText;

    /**
     * Current bearer token
     */
    string bearerToken;

    /**
     * Current API token
     */
    string apiToken;

    /**
     * Linked service account
     */
    AccountIdentifier serviceAccount;
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
     * API endpoint address
     */
    string hostAddress;

    /**
     * Public key for the instance
     */
    string publicKey;

    /**
     * Status
     */
    EndpointStatus status;

    /**
     * Special display text
     */
    string statusText;

    /**
     * Current bearer token
     */
    string bearerToken;

    /**
     * Current API token
     */
    string apiToken;

    /**
     * Linked service account
     */
    AccountIdentifier serviceAccount;
}
