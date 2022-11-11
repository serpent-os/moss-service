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
import std.path : buildPath;
import std.file : exists, rmdirRecurse, mkdir;
import vibe.d;
import core.sync.mutex;

/**
 * Static subpaths for our token disk storage
 */
private enum TokenPaths : string
{
    Seed = ".seed",
    PublicKey = ".pubkey",
    PrivateKey = ".privkey",
}

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
        keyMut = new shared Mutex();
        initSeed();
        lockPrivate();
    }

    /**
     * Handle cleanups
     */
    void close() @safe
    {
        unlockPrivate();
    }

private:

    /**
     * Initialise our Random Seed
     *
     * Throws: Exception if the stored seed on disk is invalid
     */
    void initSeed() @safe
    {
        immutable seedPath = stateDir.buildPath(TokenPaths.Seed);
        if (seedPath.exists)
        {
            auto tempSeed = readFile(seedPath);
            enforce(tempSeed.length == seed.length, "Invalid TokenSeed file");
            seed = tempSeed;
            return;
        }

        /* Create a new seed. */
        seed = createSeed();
        writeFile(NativePath(seedPath), seed);
    }

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

    /**
     * Locking ops
     */
    shared Mutex keyMut;
}

@("Ensure token manager ... works")
@safe unittest
{
    immutable testPath = ".statePath";
    scope (exit)
    {
        testPath.rmdirRecurse();
    }
    if (testPath.exists)
    {
        testPath.rmdirRecurse();
    }
    testPath.mkdir();
    auto tm = new TokenManager(testPath);
}
