import Vapor
import JWT

struct UserAuthenticator: AsyncJWTAuthenticator {
    typealias Payload = App.Payload
    
    func authenticate(jwt: Payload, for request: Vapor.Request) async throws {
        request.auth.login(jwt)
    }
}
