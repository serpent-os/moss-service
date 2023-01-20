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

/**
 * Simple mechanism to determine the work a node is doing.
 * We may extend this in future for "offline", cleaning, etc.
 */
public enum WorkStatus
{
    /**
     * Doing nothing
     */
    Idle = 0,

    /**
     * Doing something
     */
    Working,
}

/**
 * Well known status for an endpoint undergoing configuration
 */
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

    /* Banned from further use. (signature change, etc) */
    Forbidden,

    /* Previously working, lost contact */
    Unreachable,
}

public mixin template CoreEndpoint()
{
    /**
     * Status
     */
    EndpointStatus status;

    /**
     * Where do we find the endpoint?
     */

    string hostAddress;

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
     * The instance public key
     */
    string publicKey;

    /**
     * Linked service account
     */
    AccountIdentifier serviceAccount;
}

/**
 * Persistence of a vessel endpoint
 */
public @Model struct VesselEndpoint
{
    mixin CoreEndpoint;

    /**
     * Unique identifier for the endpoint
     */
    @PrimaryKey string id;
}

/**
 * Persistence of an avalanche endpoint
 */
public @Model struct AvalancheEndpoint
{
    mixin CoreEndpoint;

    /**
     * Unique identifier for the endpoint
     */
    @PrimaryKey string id;

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
     * What is this builder doing?
     */
    WorkStatus workStatus = WorkStatus.Idle;
}

/**
 * Persistence of a summit endpoint
 */
public @Model struct SummitEndpoint
{
    mixin CoreEndpoint;

    /**
     * Unique identifier for the endpoint
     */
    @PrimaryKey string id;
}
