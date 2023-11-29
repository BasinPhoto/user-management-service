import Vapor
import VaporToOpenAPI

struct LoginResponse: Content {
    let user: UserDTO
    let accessToken: String
    let refreshToken: String
}

extension LoginResponse: WithExample {
    static var example: LoginResponse {
        LoginResponse(
            user: UserDTO(
                id: UUID(),
                fullName: "Name Surname",
                email: "user@mail.com",
                isAdmin: false),
            accessToken: "access_token",
            refreshToken: "refresh_token")
    }
}
