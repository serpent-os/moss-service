/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.tokens.manager;
 *
 * Token and pair management for web applications
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.tokens.manager;

import moss.service.tokens;
import libsodium;

/**
 * Provide token management facilities.
 */
public final class TokenManager
{
    @disable this();

    /**
     * Construct a new TokenManager with the given state directory
     */
    this(string stateDir) @safe
    {
        this.stateDir = stateDir;
    }

private:

    /**
     * State directory for persistence
     */
    string stateDir;

    /**
     * Instance private signing pair
     */
    TokenSigningPair signingPair;

    /**
     * Instance specific seed
     */
    TokenSeed seed;
}
