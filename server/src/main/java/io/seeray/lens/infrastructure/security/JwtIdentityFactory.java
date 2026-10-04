package io.seeray.lens.infrastructure.security;

import io.quarkus.security.credential.TokenCredential;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.seeray.lens.application.JwtService;
import io.seeray.lens.domain.auth.AppUser;
import io.seeray.lens.domain.auth.UserStatus;
import io.seeray.lens.domain.common.ControlPlaneException;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import java.security.Principal;

@ApplicationScoped
public class JwtIdentityFactory {
    private final JwtService jwt;

    public JwtIdentityFactory(JwtService jwt) {
        this.jwt = jwt;
    }

    @Transactional
    public SecurityIdentity authenticate(String value, TokenCredential credential) {
        JwtService.Claims claims = jwt.verifyClaims(value);
        AppUser user = AppUser.findById(claims.userId());
        if (user == null || user.status == UserStatus.DISABLED || user.authVersion != claims.authVersion())
            throw new ControlPlaneException(401, "INVALID_ACCESS_TOKEN", "Access token is invalid or revoked");
        return QuarkusSecurityIdentity.builder()
                .setPrincipal((Principal) () -> user.id.toString())
                .addCredential(credential)
                .addAttribute("systemAdmin", user.systemAdmin)
                .addAttribute("mustChangePassword", user.mustChangePassword)
                .build();
    }
}
