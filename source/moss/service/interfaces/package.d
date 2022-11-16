/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.interfaces
 *
 * Contains shared API definitions for service implementation
 *
 * Note that all reference to tokens are based on the assumption of
 * using Base64URINoPadding strings in conjunction with our EdDSA
 * JWT implementation (tokens.d) based on libsodium.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.service.interfaces;

import vibe.d;

import moss.service.models.endpoints : EndpointStatus;
import vibe.web.auth;

/**
 * Enumeration of endpoints
 */
public struct VisibleEndpoint
{
    string id;
    string hostAddress;
    string publicKey;
    EndpointStatus status;
}

/**
 * There are known enrolment roles that
 * form a promise in the handshake process
 */
public enum EnrolmentRole
{
    /**
     * Errornous enrolment
     */
    Unknown = 0,

    /**
     * Assigned client should be a builder
     */
    Builder,

    /**
     * Assigned client should be a repo manager
     */
    RepositoryManager,

    /**
     * Assigned client should be a hub
     */
    Hub,
}

/**
 * Contains details of the service issuing the enrolment request
 */
public struct ServiceIssuer
{
    /**
     * Encoded public key for the issuer
     */
    string publicKey;

    /**
     * Valid callback base URL for handshakes
     */
    string url;

    /**
     * The service issuers role, i.e. Hub
     */
    EnrolmentRole role = EnrolmentRole.Unknown;
}

/**
 * Core tenant in the Enrolment API
 */
public struct ServiceEnrolmentRequest
{
    /**
     * The issuer of the request
     */
    ServiceIssuer issuer;

    /**
     * The issueing token assigned to the service
     */
    string issueToken;

    /**
     * The role assigned to the service
     */
    EnrolmentRole role;
}

/**
 * The Enrolment API is a specialist API
 * focused on service enrolment with tokens
 *
 * The basic workflow will involve a service issuing
 * a valid .enrol() call on the target, with the target
 * then replying with either a .decline() or .accept()
 * call issuing the corresponding token sets.
 */
@requiresAuth @path("api/v1/services")
public interface ServiceEnrolmentAPI
{
    /**
     * Enrol the service
     *
     * At this point, no authentication is in place. Handshake part 1.
     */
    @path("enrol") @method(HTTPMethod.POST)
    @noAuth void enrol(ServiceEnrolmentRequest request) @safe;

    /**
     * Safely enumerate endpoints
     */
    @auth((Role.web | Role.API) & Role.accessToken & Role.notExpired)
    @path("enumerate") @method(HTTPMethod.GET) VisibleEndpoint[] enumerate() @safe;

    /**
     * Accept an enrolment request
     *
     * Params:
     *      request = Handshake part 2
     *
     * This completes the pairing process. If pairing is not
     * possible, raise an error.
     */
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.bearerToken)
    @path("accept") @method(HTTPMethod.POST) void accept(ServiceEnrolmentRequest request) @safe;

    /**
     * Decline an enrolment request
     */
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.bearerToken)
    @path("decline") @method(HTTPMethod.POST) void decline() @safe;

    /**
     * Get a new API token
     *
     * The current bearer token must be used to get a new access token
     */
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.bearerToken)
    @path("refresh_token") @method(HTTPMethod.GET) string refreshToken() @safe;

    /**
     * Get a new Issue Token - old token may be expired
     *
     * The existing Issue token will be replaced
     */
    @auth(Role.API & Role.serviceAccount & Role.bearerToken)
    @path("refresh_issue_token") @method(HTTPMethod.GET) string refreshIssueToken() @safe;

    /**
     * End relationship of services
     */
    @auth(Role.notExpired & Role.API & Role.serviceAccount & Role.bearerToken)
    @path("leave") @method(HTTPMethod.POST)
    void leave() @safe;
}
