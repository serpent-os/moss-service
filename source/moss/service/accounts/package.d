/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.accounts
 *
 * Account management + auth
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.accounts;

public import moss.service.accounts.auth;
public import moss.service.accounts.manager;
public import moss.service.accounts.web;

/**
 * All service accounts are prefixed with svc- and cannot be used
 * by normal users.
 */
public static immutable string serviceAccountPrefix = "@";
