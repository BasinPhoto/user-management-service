import Vapor
import VaporToOpenAPI

struct ResetPasswordRequest: Content {
    let email: String
}

extension ResetPasswordRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

extension ResetPasswordRequest: WithExample {
    static var example: ResetPasswordRequest {
        ResetPasswordRequest(email: "some@mail.com")
    }
}
