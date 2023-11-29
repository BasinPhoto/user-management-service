import Vapor
import VaporToOpenAPI

struct TokenQuery: Content {
    let token: String
}

extension TokenQuery: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("token", as: String.self, is: !.empty)
    }
}

extension TokenQuery: WithExample {
    static var example: TokenQuery {
        TokenQuery(token: "sometoken")
    }
}
