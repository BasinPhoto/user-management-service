import Vapor
import VaporToOpenAPI

struct SwaggerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("swagger.json", use: apiHandler).excludeFromOpenAPI()
        routes.get(use: apiHandler).excludeFromOpenAPI()
    }
    
    private func apiHandler(req: Request) throws -> OpenAPIObject {
        req.application.routes
            .openAPI(
                info: InfoObject(
                    title: "API Swagger",
                    summary: "Service for user authentication",
                    description: """
                    Service for authentication users.
                    Complete cycle of management.
                    Register, login, recovery and access token refresh.
                    """,
                    license: LicenseObject(
                        name: "License",
                        identifier: "MIT",
                        url: URL(string: "https://opensource.org/licenses/MIT")
                    ),
                    version: Version(stringLiteral: "1.0")
                ),
                servers: [
                    ServerObject(stringLiteral: "http://localhost:8080/")
                ]
            )
    }
}
