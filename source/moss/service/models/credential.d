/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.models.credential
 *
 * Credential storage. Separated from User model for security
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.models.credential;

public import moss.db.keyvalue.orm;

public import moss.service.models.account : AccountIdentifier;

/**
 * Access credentials for *user* accounts
 */
public @Model struct Credential
{
    /**
     * Each Credential is keyed to a user account
     */
    @PrimaryKey AccountIdentifier id;

    /**
     * Hashed password storage
     */
    string hashedPassword;
}
