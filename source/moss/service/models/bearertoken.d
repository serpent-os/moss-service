/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.models.bearertoken
 *
 * Persistence for Bearer Tokens
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.models.bearertoken;

public import moss.db.keyvalue.orm;
public import moss.service.models.account : AccountIdentifier;
public import std.stdint : uint64_t;

/**
 * BearerToken stores the remote-access token required for
 * a service account to authorize against the system DB
 *
 * This token is generated locally and verifed using our
 * local public key, and is issued for the purpose of remote
 * service accounts (summit <-> avalanche)
 */
public @Model struct BearerToken
{
    /**
     * Account ID
     */
    @PrimaryKey AccountIdentifier id;

    /**
     * Raw token string
     */
    string rawToken;

    /**
     * When does the token expire?
     */
    uint64_t expiryUTC;
}
