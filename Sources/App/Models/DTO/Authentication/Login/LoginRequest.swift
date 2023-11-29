import Vapor
import VaporToOpenAPI

struct LoginRequest: Content {
    let email: String
    let password: String
}

extension LoginRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: !.empty)
    }
}

extension LoginRequest: WithExample {
    static var example: LoginRequest {
        LoginRequest(
            email: "some@mail.com",
            password: "12345678")
    }
}
