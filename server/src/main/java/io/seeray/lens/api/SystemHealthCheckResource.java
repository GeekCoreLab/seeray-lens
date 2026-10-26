package io.seeray.lens.api;

import io.quarkus.security.Authenticated;
import io.seeray.lens.application.SystemAdminAccess;
import io.seeray.lens.application.SystemHealthCheckService;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Authenticated
@Path("/api/v1/admin/health-check")
@Produces(MediaType.APPLICATION_JSON)
public class SystemHealthCheckResource {
    private final SystemAdminAccess access;
    private final SystemHealthCheckService checks;

    public SystemHealthCheckResource(SystemAdminAccess access, SystemHealthCheckService checks) {
        this.access = access;
        this.checks = checks;
    }

    @GET
    public SystemHealthCheckService.Report currentReport() {
        access.require();
        return checks.currentReport();
    }
}
