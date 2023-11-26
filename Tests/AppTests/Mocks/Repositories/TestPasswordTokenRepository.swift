@testable import App
import Vapor

final class TestPasswordTokenRepository: PasswordTokenRepository, TestRepository {
    var eventLoop: EventLoop
    var tokens: [PasswordToken]
    
    init(tokens: [PasswordToken], eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.tokens = tokens
    }
    
    func find(userID: UUID) async throws -> PasswordToken? {
        let token = tokens.first(where: { $0.$user.id == userID })
        return token
    }
    
    func find(token: String) async throws -> PasswordToken? {
        let token = tokens.first(where: { $0.token == token })
        return token
    }
    
    func count() async throws -> Int {
        return tokens.count
    }
    
    func create(_ passwordToken: PasswordToken) async throws {
        tokens.append(passwordToken)
    }

    
    func delete(_ passwordToken: PasswordToken) async throws {
        tokens.removeAll(where: { passwordToken.id == $0.id })
    }
    
    func delete(for userID: UUID) async throws {
        tokens.removeAll(where: { $0.$user.id == userID })
    }
}
