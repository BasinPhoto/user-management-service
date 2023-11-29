import Vapor
import VaporToOpenAPI

struct AccessTokenResponse: Content {
    let refreshToken: String
    let accessToken: String
}

extension AccessTokenResponse: WithExample {
    static var example: AccessTokenResponse {
        AccessTokenResponse(
            refreshToken: "refresh_token",
            accessToken: "access_token"
        )
    }
}
