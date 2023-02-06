/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.interfaces
 *
 * Shared interfaces for service implementations
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.interfaces;

public import moss.service.interfaces.avalanche;
public import moss.service.interfaces.endpoints;
public import moss.service.interfaces.summit;

/**
 * Collectable assets passed between the infrastructure
 */
public enum CollectableType : string
{
    /**
     * A build log file
     */
    Log = "log",

    /**
     * The build manifest
     */
    Manifest = "manifest",

    /**
     * A binary package
     */
    Package = "package",
}

/**
 * An asset for passing between infrastructure components,
 * such as a package or log file
 */
public struct Collectable
{
    /**
     * Type of collectable
     */
    CollectableType type;

    /**
     * Fully qualified URL, must be set correctly by each component
     */
    string uri;

    /**
     * Hash sum for the asset
     */
    string sha256sum;
}
