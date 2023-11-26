@testable import App
import Vapor

class TestEmailTokenRepository: EmailTokenRepository, TestRepository {
    var tokens: [EmailToken]
    var eventLoop: EventLoop
    
    init(tokens: [EmailToken] = [], eventLoop: EventLoop) {
        self.tokens = tokens
        self.eventLoop = eventLoop
    }
    
    func find(token: String) async throws -> EmailToken? {
        let token = tokens.first(where: { $0.token == token })
        return token
    }
    
    func create(_ emailToken: EmailToken) async throws {
        tokens.append(emailToken)
    }
    
    func delete(_ emailToken: EmailToken) {
        tokens.removeAll(where: { $0.id == emailToken.id })
    }
    
    
    func find(userID: UUID) async throws -> EmailToken? {
        let token = tokens.first(where: { $0.$user.id == userID })
        return token
    }
}
