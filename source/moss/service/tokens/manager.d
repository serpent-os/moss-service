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
import std.base64 : Base64URLNoPadding;

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
        initSigningPair();

        /* Public key as usable string */
        _publicKey = Base64URLNoPadding.encode(signingPair.publicKey);
        lockPrivate();
    }

    /**
     * Handle cleanups
     */
    void close() @safe
    {
        unlockPrivate();
    }

    /**
     * Returns: Base64URLNoPadding encoded public key string
     */
    pure @property auto publicKey() @safe @nogc nothrow const
    {
        return _publicKey;
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
            enforce(tempSeed.length == TokenSeed.sizeof, "Invalid TokenSeed file");
            seed = cast(TokenSeed) tempSeed[0 .. TokenSeed.sizeof];
            return;
        }

        /* Create a new seed. */
        seed = createSeed();
        writeFile(NativePath(seedPath), seed);
    }

    /**
     * Initialise our signing pair
     *
     * Throws: Exception if the keys on disk are corrupt
     */
    void initSigningPair() @safe
    {
        immutable privPath = stateDir.buildPath(TokenPaths.PrivateKey);
        immutable pubPath = stateDir.buildPath(TokenPaths.PublicKey);

        /* Load the keypair from disk */
        if (privPath.exists && pubPath.exists)
        {
            auto pub = readFile(pubPath);
            auto priv = readFile(privPath);

            enforce(pub.length == TokenPublicKey.sizeof, "Invalid public key file");
            enforce(priv.length == TokenSecretKey.sizeof, "Invalid private key file");

            /* Construct the signing pair from data */
            signingPair = TokenSigningPair(cast(TokenPublicKey) pub[0 .. TokenPublicKey.sizeof],
                    cast(TokenSecretKey) priv[0 .. TokenSecretKey.sizeof]);
        }

        /* Generate new pair */
        signingPair = TokenSigningPair.create(seed);
        writeFile(NativePath(privPath), signingPair.secretKey);
        writeFile(NativePath(pubPath), signingPair.publicKey);
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
     * Base64URI encoded public key string
     */
    string _publicKey;

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
    auto originalKey = tm.publicKey();
    tm.close();
    tm = new TokenManager(testPath);
    auto loadedKey = tm.publicKey();

    assert(originalKey == loadedKey, "Failed to load old keys from disk");
    logInfo(format!"Public key: %s"(originalKey));
}
