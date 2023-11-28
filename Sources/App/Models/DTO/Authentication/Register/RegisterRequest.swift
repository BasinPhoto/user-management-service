import Vapor
import VaporToOpenAPI

struct RegisterRequest: Content {
    let fullName: String
    let email: String
    let password: String
    let confirmPassword: String
}

extension RegisterRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("fullName", as: String.self, is: .count(3...))
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

extension RegisterRequest: WithExample {
    static var example: RegisterRequest {
        RegisterRequest(
            fullName: "Name Surname",
            email: "some@mail.com",
            password: "password",
            confirmPassword: "password")
    }
}

extension User {
    convenience init(from register: RegisterRequest, hash: String) throws {
        self.init(fullName: register.fullName, email: register.email, passwordHash: hash)
    }
}
