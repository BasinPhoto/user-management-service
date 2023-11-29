import Vapor
import VaporToOpenAPI

struct AccessTokenRequest: Content {
    let refreshToken: String
}

extension AccessTokenRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("refreshToken", as: String.self, is: !.empty, required: true)
    }
}

extension AccessTokenRequest: WithExample {
    static var example: AccessTokenRequest {
        AccessTokenRequest(refreshToken: "refresh_token")
    }
}
