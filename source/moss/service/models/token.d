/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.models.token
 *
 * Token encapsulation
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.models.token;

public import moss.db.keyvalue.orm;
public import moss.service.models.user : UserIdentifier;
public import std.stdint : uint64_t, uint8_t;

/**
 * Our UID is the biggest number we can get.
 */
public alias TokenIdentifier = uint64_t;

/**
 * A token has certain validity constraints
 */
public enum TokenType : uint8_t
{
    /**
     * Issued solely for API use
     */
    RemoteAccess,

    /**
     * Issued for a session, ensures timeouts
     * work correctly, etc.
     */
    Session,

    /**
     * API refresh token, required to grab a new token
     * when the current one is expired.
     */
    Refresh,
}

/**
 * A token is mapped to a user - but uniquely by the
 * raw string.
 */
public @Model struct Token
{

    /**
     * Unique identifier for the group
     */
    @PrimaryKey @AutoIncrement TokenIdentifier id;

    /**
     * Unique name
     */
    @Indexed string rawToken;

    /**
     * Who owns the token
     */
    UserIdentifier user;

    /**
     * Constraints on the token
     */
    TokenType type;
}
