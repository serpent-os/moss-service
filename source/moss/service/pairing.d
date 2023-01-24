/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.service.pairing
 *
 * Shared pairing functionality
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.service.pairing;

import vibe.d;

import moss.service.accounts;
import moss.service.models;
import moss.service.context;
import moss.service.tokens;
import moss.core.errors;
import moss.service.interfaces.endpoints;

public alias PairingResult = Optional!(Success, Failure);
public alias TokenCreationResult = Optional!(BearerToken, Failure);

/** 
 * The PairingManager encapsulates use of the account and token
 * facilities to simplify the various token management processes
 * required to keep connections between the infrastructure components
 * secure and fresh.
 */
public final class PairingManager
{
    @disable this();

    /** 
     * Construct a new PairingManager
     * Params:
     *   context = global shared context
     */
    this(ServiceContext context, string issuer, string instanceURI) @safe
    {
        this.context = context;
        this.issuer = issuer;
        this.instanceURI = instanceURI;
    }

    /** 
     * Create an account for the given endpoint identity
     * This is required for incoming and outgoing connections, regardless.
     *
     * Note: The EndpointStatus should be set appropriately.
     *
     * Params:
     *   endpoint = Endpoint
     */
    auto createEndpointAccount(E)(ref E endpoint) @safe
    {
        immutable serviceAccountID = format!"%s%s"(serviceAccountPrefix, endpoint.id);
        return context.accountManager.registerService(serviceAccountID, endpoint.adminEmail);
    }

    /** 
     * Create a bearer token for incoming connections from the endpoint
     * Params:
     *   endpoint = Endpoint
     *   serviceAccount = The account created by createEndpointAccount
     *   audience = The audience (ie. avalanche)
     */
    TokenCreationResult createBearerToken(E)(ref E endpoint,
            scope Account serviceAccount, string audience) @safe
    {
        TokenPayload payload;
        payload.iss = issuer;
        payload.sub = serviceAccount.username;
        payload.uid = serviceAccount.id;
        payload.act = serviceAccount.type;
        payload.aud = "avalanche";
        Token bearer = context.tokenManager.createBearerToken(payload);

        return context.tokenManager.signToken(bearer).match!((TokenError err) {
            return cast(TokenCreationResult) fail(err.message);
        }, (string signedToken) {
            BearerToken storedToken;
            storedToken.id = serviceAccount.id;
            storedToken.rawToken = signedToken;
            storedToken.expiryUTC = bearer.payload.exp;
            immutable err = context.accountManager.setBearerToken(serviceAccount, storedToken);
            if (err.isNull)
            {
                return cast(TokenCreationResult) storedToken;
            }
            return cast(TokenCreationResult) fail(err.message);
        });
    }

    /** 
     * Enrol with an endpoint
     *
     * Params:
     *   endpoint = endpoint
     *   bearerTolen = as returned by createBearerToken
     *   ourRole = Our own role in the relationship (usually Hub)
     *   theirRole = The role of the endpoint
     */
    PairingResult enrolWith(E)(ref E endpoint, scope const BearerToken bearerToken,
            EnrolmentRole ourRole, EnrolmentRole theirRole) @safe
    {
        auto rapi = new RestInterfaceClient!ServiceEnrolmentAPI(endpoint.hostAddress);

        /* Our details */
        ServiceEnrolmentRequest req;
        req.issuer.publicKey = context.tokenManager.publicKey;
        req.issuer.role = ourRole;
        req.issuer.url = instanceURI;

        /* Their details */
        req.role = theirRole;
        req.issueToken = bearerToken.rawToken;

        try
        {
            rapi.enrol(req);
            endpoint.status = EndpointStatus.AwaitingAcceptance;
            endpoint.statusText = "Awaiting acceptance";
        }
        catch (Exception ex)
        {
            endpoint.status = EndpointStatus.Failed;
            endpoint.statusText = format!"Failed: %s"(ex.message);
        }

        /* Update the model */
        immutable err = context.appDB.update((scope tx) => endpoint.save(tx));
        enforceHTTP(err.isNull, HTTPStatus.internalServerError, err.message);

        return endpoint.status == EndpointStatus.AwaitingAcceptance
            ? cast(PairingResult) Success() : cast(PairingResult) fail(endpoint.statusText);
    }

    /** 
     * Accept an rolment request from another remote instance
     *
     * Params:
     *   endpoint = endpoint
     *   bearerToken = as returned by createBearerToken
     *   ourRole = Our role in the relationship (i.e. Builder)
     *   theirRole = Their role in the relationship (i.e. Summit)
     * Returns: A pairing result
     */
    PairingResult acceptFrom(E)(ref E endpoint, scope const ref BearerToken bearerToken,
            EnrolmentRole ourRole, EnrolmentRole theirRole) @safe
    {
        auto rapi = new RestInterfaceClient!ServiceEnrolmentAPI(endpoint.hostAddress);
        rapi.requestFilter = (req) {
            req.headers["Authorization"] = format!"Bearer %s"(bearerToken.rawToken);
        };

        /* Our details */
        ServiceEnrolmentRequest req;
        req.issuer.publicKey = context.tokenManager.publicKey;
        req.issuer.role = ourRole;
        req.issuer.url = instanceURI;

        /* Their details */
        req.role = theirRole;
        req.issueToken = bearerToken.rawToken;

        try
        {
            rapi.enrol(req, NullableToken());
            endpoint.status = EndpointStatus.Operational;
            endpoint.statusText = "Fully operational";
        }
        catch (Exception ex)
        {
            endpoint.status = EndpointStatus.Failed;
            endpoint.statusText = format!"Failed: %s"(ex.message);
        }

        /* Update the model */
        immutable err = context.appDB.update((scope tx) => endpoint.save(tx));
        enforceHTTP(err.isNull, HTTPStatus.internalServerError, err.message);

        return endpoint.status == EndpointStatus.Operational
            ? cast(PairingResult) Success() : cast(PairingResult) fail(endpoint.statusText);
    }

private:

    ServiceContext context;
    string issuer;
    string instanceURI;
}
