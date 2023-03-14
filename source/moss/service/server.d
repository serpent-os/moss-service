/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.server
 *
 * Basic server code reused by all moss services
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.server;

import moss.service.context;
import vibe.d;
import std.signals;
import std.path : buildPath;

/**
 * A server can be in one exclusive mode
 */
public enum ApplicationMode
{
    Setup,
    Main,
}

/**
 * Each Server supports a main application and setup application
 * to make life generally easier for development purposes.
 */
public abstract class Application
{
    /** 
     * Init the app
     *
     * Params:
     *   context = global shared context
     */
    @noRoute abstract void initialize(ServiceContext context) @safe;

    /** 
     * Application must close now
     */
    @noRoute abstract void close();

    /** 
     * Returns: The applications private router
     */
    @noRoute pure @property URLRouter router() @safe @nogc nothrow;

    /**
     * The SetupApp should emit this to transition into the main app mode
     */
    @noRoute mixin Signal!() completed;
}

/** 
 * The Server class is responsible for switching between setup and main application
 * whilst handling all routing
 *
 * Params:
 *      S = SetupApplication type
 *      M = MainApplication type
 */
public final class Server(S : Application, M:
        Application)
{
    public alias SetupApp = S;
    public alias MainApp = M;

    @disable this();

    /**
     * Construct a new Server
     *
     * Params:
     *      rootDirectory = Root directory to operate from
     */
    this(string rootDirectory) @safe
    {
        _context = new ServiceContext(rootDirectory);

        _serverSettings = new HTTPServerSettings();
        serverSettings.sessionStore = new MemorySessionStore;
        serverSettings.useCompressionIfPossible = true;
        serverSettings.disableDistHost = true;
        /* TODO: Only enable .secure when using SSL */
        serverSettings.sessionOptions = SessionOption.httpOnly;

        /* File settings for /static/ serving */
        fileSettings = new HTTPFileServerSettings();
        fileSettings.serverPathPrefix = "/static";
        fileSettings.options = HTTPFileServerOption.failIfNotFound;
        fileHandler = serveStaticFiles(context.rootDirectory.buildPath("static/"), fileSettings);
    }

    /** 
     * Close the Server, stop listening
     */
    void close() @safe
    {
        if (_setupApp !is null)
        {
            _setupApp.close();
        }
        if (_mainApp !is null)
        {
            _mainApp.close();
        }
        listener.stopListening();
    }

    /** 
     * Start serving + servicing requests
     */
    void start() @safe
    {
        listener = listenHTTP(_serverSettings, &handle);
        requireApp();
    }

    /** 
     * Set the application mode in use
     * Params:
     *   mode = the new mode
     */
    pure @property void mode(ApplicationMode mode) @safe @nogc nothrow
    {
        _mode = mode;
    }

    /** 
     * Returns: the Application mode in use
     */
    pure @property ApplicationMode mode() @safe @nogc nothrow const
    {
        return _mode;
    }

    /** 
     * Returns: The setup application instance
     */
    pure @property SetupApp setupApp() @safe @nogc nothrow
    {
        return _setupApp;
    }

    /** 
     * Returns: The main application instance
     */
    pure @property MainApp mainApp() @safe @nogc nothrow
    {
        return _mainApp;
    }

    /** 
     * Returns: The global context
     */
    pure @property ServiceContext context() @safe @nogc nothrow
    {
        return _context;
    }

    /** 
     * Returns: The settings we use for connections
     */
    pragma(inline, true) pure @property HTTPServerSettings serverSettings() @safe @nogc nothrow
    {
        return _serverSettings;
    }

    /** 
     * 
     * Params:
     *   request = The incoming request
     *   response = The outgoing response
     */
    void handle(scope HTTPServerRequest request, scope HTTPServerResponse response) @safe
    {
        URLRouter designatedRouter;

        final switch (_mode)
        {
        case ApplicationMode.Setup:
            designatedRouter = _setupApp.router;
            break;
        case ApplicationMode.Main:
            designatedRouter = _mainApp.router;
            break;
        }

        /**
         * Make sure we have an available router!
         */
        if (designatedRouter !is null)
        {
            designatedRouter.handleRequest(request, response);
        }
    }

private:

    /** 
     * Ensure the right application is loaded
     */
    void requireApp() @safe
    {
        final switch (mode)
        {
        case ApplicationMode.Setup:
            if (_mainApp !is null)
            {
                _mainApp.close();
                _mainApp = null;
            }
            if (_setupApp is null)
            {
                _setupApp = new SetupApp();
                () @trusted { _setupApp.completed.connect(&onSetupComplete); }();
                _setupApp.initialize(context);
                _setupApp.router.get("/static/*", fileHandler);

            }
            break;
        case ApplicationMode.Main:
            if (_setupApp !is null)
            {
                _setupApp.close();
                _setupApp = null;
            }
            if (_mainApp is null)
            {
                _mainApp = new MainApp();
                _mainApp.initialize(context);
                _mainApp.router.get("/static/*", fileHandler);
            }
            break;
        }
    }

    /** 
     * Handle transition from setup to main app
     */
    void onSetupComplete() @safe
    {
        _mode = ApplicationMode.Main;
        requireApp();
    }

    MainApp _mainApp;
    SetupApp _setupApp;
    ServiceContext _context;
    ApplicationMode _mode = ApplicationMode.Setup;
    HTTPListener listener;
    HTTPFileServerSettings fileSettings;
    HTTPServerSettings _serverSettings;
    HTTPServerRequestDelegate fileHandler;
}
