/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.models.group
 *
 * Group encapsulation
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.models.group;

public import moss.db.keyvalue.orm;
public import moss.service.models.user : UserIdentifier;
public import std.stdint : uint64_t, uint8_t;

/**
 * Our UID is the biggest number we can get.
 */
public alias GroupIdentifier = uint64_t;

/**
 * A Group is a collection of users
 */
public @Model struct Group
{

    /**
     * Unique identifier for the group
     */
    @PrimaryKey @AutoIncrement GroupIdentifier id;

    /** 
     * Unique slug for the whole instance
     */
    @Indexed string slug;

    /**
     * Display name
     */
    string name;

    /**
     * All the users within our group
     */
    UserIdentifier[] users;
}
