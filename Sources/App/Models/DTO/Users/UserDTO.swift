import Vapor
import VaporToOpenAPI

struct UserDTO: Content {
    let id: UUID?
    let fullName: String
    let email: String
    let isAdmin: Bool
    
    init(id: UUID? = nil, fullName: String, email: String, isAdmin: Bool) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.isAdmin = isAdmin
    }
    
    init(from user: User) {
        self.init(id: user.id, fullName: user.fullName, email: user.email, isAdmin: user.isAdmin)
    }
}

extension UserDTO: WithExample {
    static var example: UserDTO {
        .init(fullName: "Name Surname", email: "user@mail.com", isAdmin: false)
    }
}
