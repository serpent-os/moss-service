/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.models.account
 *
 * Account encapsulation
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.models.account;

public import moss.db.keyvalue.orm;
public import moss.service.models.group : GroupIdentifier;
public import std.stdint : uint64_t, uint8_t;

/**
 * Our UID is the biggest number we can get.
 */
public alias AccountIdentifier = uint64_t;

/**
 * An account falls into 3 distinct categories
 */
public enum AccountType : uint8_t
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
 * Account storage
 */
public @Model struct Account
{

    /**
     * Unique identifier for the account
     */
    @PrimaryKey @AutoIncrement AccountIdentifier id;

    /**
     * Unique username
     */
    @Indexed string username;

    /** 
     * Primary account username
     */
    string email;

    /**
     * What kind of user is this.. ?
     */
    AccountType type;

    /**
     * Groups that the user is a member of
     */
    GroupIdentifier[] groups;
}
