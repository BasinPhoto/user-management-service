@testable import App
import Vapor
import Fluent

class TestUserRepository: UserRepository, TestRepository {
    var users: [User]
    var eventLoop: EventLoop
    
    init(users: [User] = [User](), eventLoop: EventLoop) {
        self.users = users
        self.eventLoop = eventLoop
    }
    
    func create(_ user: User) async throws {
        user.id = UUID()
        users.append(user)
    }
    
    func delete(id: UUID) async throws {
        users.removeAll(where: { $0.id == id })
    }
    
    func all() async throws -> [User] {
        users
    }
    
    func find(id: UUID?) async throws -> User? {
        let user = users.first(where: { $0.id == id })
        return user
    }
    
    func find(email: String) async throws -> User? {
        let user = users.first(where: { $0.email == email })
        return user
    }
    
    func set<Field>(_ field: KeyPath<User, Field>, to value: Field.Value, for userID: UUID) async throws where Field : QueryableProperty, Field.Model == User {
        let user = users.first(where: { $0.id == userID })!
        user[keyPath: field].value = value
    }
    
    func count() async throws -> Int {
        users.count
    }
}
