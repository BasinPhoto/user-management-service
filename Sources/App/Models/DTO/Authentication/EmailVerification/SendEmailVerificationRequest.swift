import Vapor
import VaporToOpenAPI

struct SendEmailVerificationRequest: Content {
    let email: String
}

extension SendEmailVerificationRequest: WithExample {
    static var example: SendEmailVerificationRequest {
        SendEmailVerificationRequest(email: "some@mail.com")
    }
}
