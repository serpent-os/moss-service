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
import std.datetime;
import std.sumtype : tryMatch;
import std.exception : enforce;

/**
 * Durations for token validity
 */
private enum TokenValidity : Duration
{
    /**
     * API tokens are valid for 1 hour
     */
    API = 1.hours,

    /**
     * Bearer tokens are valid for 7 days
     */
    Bearer = 7.days,
}

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
    }

    /**
     * Returns: Base64URLNoPadding encoded public key string
     */
    pure @property auto publicKey() @safe @nogc nothrow const
    {
        return _publicKey;
    }

    /**
     * Construct a bearer token The Right Way
     *
     * Params:
     *      payload = Populated payload
     * Returns: Correct Token with expiry set
     */
    Token createBearerToken(TokenPayload payload) @safe
    {
        Token ret;
        ret.payload = payload;
        ret.payload.purpose = TokenPurpose.Authorization;
        auto now = Clock.currTime(UTC());
        ret.payload.iat = now.toUnixTime();
        ret.payload.exp = (now + TokenValidity.Bearer).toUnixTime();
        return ret;
    }

    /**
     * Construct an API token The Right Way
     *
     * Params:
     *      payload = Populated payload
     * Returns: Correct Token with expiry set
     */
    Token createAPIToken(TokenPayload payload) @safe
    {
        Token ret;
        ret.payload = payload;
        auto now = Clock.currTime(UTC());
        ret.payload.purpose = TokenPurpose.Authentication;
        ret.payload.iat = now.toUnixTime();
        ret.payload.exp = (now + TokenValidity.API).toUnixTime();
        return ret;
    }

    /**
     * Sign and encode a token using our secret key
     *
     * Params:
     *      token = Valid input token
     * Returns: Signed + encoded token ready for use.
     */
    auto signToken(scope const ref Token token) @safe
    {
        keyMut.lock_nothrow();
        scope (exit)
        {
            keyMut.unlock_nothrow();
        }

        return token.sign(signingPair.secretKey);
    }

    /**
     * Verify a token
     *
     * Note: The token must be decoded from a JWT string
     *
     * Returns: True if the public key is valid for this token
     */
    bool verify(scope const ref Token token, TokenPublicKey pubkey) @safe @nogc const
    {
        return token.verify(pubkey);
    }

    /**
     * Verify a token against an encoded public key
     */
    bool verify(scope const ref Token token, string pubkeyString) @safe
    {
        TokenPublicKey pubkey;
        auto decoded = Base64URLNoPadding.decode(pubkeyString);
        enforceHTTP(decoded.length == TokenPublicKey.sizeof, HTTPStatus.internalServerError, "Invalid public key length");
        pubkey = decoded[0..TokenPublicKey.sizeof];
        return token.verify(pubkey);
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
    () @trusted { sodium_init(); }();

    immutable testPath = ".statePath";
    TokenManager tm;
    scope (exit)
    {
        testPath.rmdirRecurse();
    }
    if (testPath.exists)
    {
        testPath.rmdirRecurse();
    }
    testPath.mkdir();
    tm = new TokenManager(testPath);
    immutable originalKey = tm.publicKey();
    tm = new TokenManager(testPath);
    immutable loadedKey = tm.publicKey();

    assert(originalKey == loadedKey, "Failed to load old keys from disk");
    logInfo(format!"Public key: %s"(originalKey));

    Token tk = tm.createAPIToken(TokenPayload(0, 0, "user", "moss-service"));
    immutable encoded = tm.signToken(tk).tryMatch!((string s) => s);
    logInfo(format!"Encoded token: %s"(encoded));

    Token decoded = Token.decode(encoded).tryMatch!((Token tk) => tk);
    assert(tm.verify(decoded, tm.signingPair.publicKey), "Invalid signature");
    assert(decoded.payload == tk.payload, "invalid payload");
    assert(decoded.header == tk.header, "invalid header");

}
