/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.models.user
 *
 * User encapsulation
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.models.user;

public import moss.db.keyvalue.orm;
public import moss.service.models.group : GroupIdentifier;
public import std.stdint : uint64_t, uint8_t;

/**
 * Our UID is the biggest number we can get.
 */
public alias UserIdentifier = uint64_t;

/**
 * A user falls into 3 distinct categories
 */
public enum UserType : uint8_t
{
    /**
     * Real hooman user.
     */
    Standard = 0,

    /** 
     * Some kind of blessed bot account
     */
    Bot,

    /**
     * Internal service account
     */
    Service,
}

/**
 * A User is the most basic type we have, and
 * represents an access policy.
 */
public @Model struct User
{

    /**
     * Unique identifier for the user
     */
    @PrimaryKey @AutoIncrement UserIdentifier id;

    /**
     * Unique username
     */
    @Indexed string username;

    /**
     * The users hashed password (libsodium)
     */
    string hashedPassword;

    /**
     * What kind of user is this.. ?
     */
    UserType type;

    /**
     * Groups that the user is a member of
     */
    GroupIdentifier[] groups;
}
