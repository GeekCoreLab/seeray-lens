package io.seeray.lens.infrastructure.security;

import io.quarkus.security.credential.TokenCredential;
import io.quarkus.security.identity.*;
import io.quarkus.security.identity.request.TokenAuthenticationRequest;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.seeray.lens.application.ApiTokenAuthenticator;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import java.security.Principal;

@ApplicationScoped
public class JwtIdentityProvider implements IdentityProvider<TokenAuthenticationRequest> {
    private final ApiTokenAuthenticator apiTokens;
    private final JwtIdentityFactory jwtIdentityFactory;

    public JwtIdentityProvider(ApiTokenAuthenticator apiTokens, JwtIdentityFactory jwtIdentityFactory) {
        this.apiTokens = apiTokens;
        this.jwtIdentityFactory = jwtIdentityFactory;
    }

    @Override
    public Class<TokenAuthenticationRequest> getRequestType() {
        return TokenAuthenticationRequest.class;
    }

    @Override
    public Uni<SecurityIdentity> authenticate(
            TokenAuthenticationRequest request, AuthenticationRequestContext context) {
        TokenCredential credential = request.getToken();
        String value = credential.getToken();
        if (value.startsWith("srlat_")) {
            return context.runBlocking(() -> {
                ApiTokenAuthenticator.AuthenticatedToken token = apiTokens.authenticate(value);
                return QuarkusSecurityIdentity.builder()
                        .setPrincipal((Principal) () -> token.actorId().toString())
                        .addCredential(credential)
                        .addAttribute(ApiTokenAuthenticator.ATTRIBUTE_TYPE, ApiTokenAuthenticator.TYPE)
                        .addAttribute(ApiTokenAuthenticator.ATTRIBUTE_ID, token.id())
                        .addAttribute(ApiTokenAuthenticator.ATTRIBUTE_WORKSPACE_ID, token.workspaceId())
                        .addAttribute(ApiTokenAuthenticator.ATTRIBUTE_NAME, token.name())
                        .addAttribute(ApiTokenAuthenticator.ATTRIBUTE_CAN_READ, token.canRead())
                        .addAttribute(ApiTokenAuthenticator.ATTRIBUTE_CAN_WRITE, token.canWrite())
                        .build();
            });
        }
        return context.runBlocking(() -> {
            return jwtIdentityFactory.authenticate(value, credential);
        });
    }
}
