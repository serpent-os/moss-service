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
        lockPrivate();
    }

private:

    /**
     * Lock memory for the private key
     */
    void lockPrivate() @trusted
    {
        sodium_mlock(cast(void*) signingPair.secretKey.ptr, signingPair.secretKey.length);
    }

    /**
     * Unlock memory for the private key
     */
    void unlockPrivate() @trusted
    {
        sodium_munlock(cast(void*) signingPair.secretKey.ptr, signingPair.secretKey.length);
    }

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
