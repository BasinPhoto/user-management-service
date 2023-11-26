@testable import App
import Vapor
import Crypto

class TestRefreshTokenRepository: RefreshTokenRepository, TestRepository {
    var tokens: [RefreshToken]
    var eventLoop: EventLoop
    
    init(tokens: [RefreshToken] = [], eventLoop: EventLoop) {
        self.tokens = tokens
        self.eventLoop = eventLoop
    }
    
    func create(_ token: RefreshToken) async throws {
        token.id = UUID()
        tokens.append(token)
    }
    
    func find(id: UUID?) async throws -> RefreshToken? {
        let token = tokens.first(where: { $0.id == id})
        return token
    }
    
    func find(token: String) async throws -> RefreshToken? {
        let token = tokens.first(where: { $0.token == token })
        return token
    }
    
    func delete(_ token: RefreshToken) async throws {
        tokens.removeAll(where: { $0.id == token.id })
     }
    
    func count() async throws -> Int {
        return tokens.count
    }
    
    func delete(for userID: UUID) async throws {
        tokens.removeAll(where: { $0.$user.id == userID })
    }
}
