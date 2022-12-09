/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.context
 *
 * Contextual storage - DBs, etc.
 * Highly opinionated context type that expects a single application
 * database, with a separate accounts database.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.context;

public import moss.db.keyvalue;
public import moss.service.accounts;
public import moss.service.tokens.manager;
import std.file : mkdirRecurse;
import std.path : buildPath;
import vibe.d;

/**
 * Shared databases, etc.
 */
public final class ServiceContext
{
    @disable this();

    /**
     * Construct new context with the given root directory
     */
    this(string rootDirectory) @safe
    {
        this._rootDirectory = rootDirectory;
        immutable statePath = rootDirectory.buildPath("state");
        this._dbPath = statePath.buildPath("db");
        _dbPath.mkdirRecurse();
        this._cachePath = statePath.buildPath("cache");
        _cachePath.mkdirRecurse();
        this._statePath = statePath;

        /* Get token manager up and running */
        _tokenManager = new TokenManager(statePath);
        logInfo(format!"Instance pubkey: %s"(tokenManager.publicKey));

        /* open our DB */
        Database.open(format!"lmdb://%s"(dbPath.buildPath("app")),
                DatabaseFlags.CreateIfNotExists).tryMatch!((Database db) {
            _appDB = db;
        });

        /* Establish account management */
        _accountManager = new AccountManager(dbPath.buildPath("accounts"));
    }

    /**
     * Release all resources
     */
    void close() @safe
    {
        _accountManager.close();
        _appDB.close();
    }

    /**
     * Returns: The current tokenManager
     */
    pragma(inline, true) pure @property TokenManager tokenManager() @safe @nogc nothrow
    {
        return _tokenManager;
    }

    /**
     * Returns: the account manager
     */
    pragma(inline, true) pure @property AccountManager accountManager() @safe @nogc nothrow
    {
        return _accountManager;
    }

    /**
     * Returns: the application database
     */
    pragma(inline, true) pure @property Database appDB() @safe @nogc nothrow
    {
        return _appDB;
    }

    /**
     * Returns: root directory
     */
    pragma(inline, true) pure @property string rootDirectory() @safe @nogc nothrow const
    {
        return _rootDirectory;
    }

    /**
     * Returns: the database path
     */
    pragma(inline, true) pure @property string dbPath() @safe @nogc nothrow const
    {
        return _dbPath;
    }

    /**
     * Returns: the cache path
     */
    pragma(inline, true) pure @property string cachePath() @safe @nogc nothrow const
    {
        return _cachePath;
    }

    /**
     * Returns: The state path
     */
    pragma(inline, true) pure @property string statePath() @safe @nogc nothrow const
    {
        return _statePath;
    }

private:

    TokenManager _tokenManager;
    AccountManager _accountManager;
    Database _appDB;

    string _rootDirectory;
    string _dbPath;
    string _cachePath;
    string _statePath;
}
