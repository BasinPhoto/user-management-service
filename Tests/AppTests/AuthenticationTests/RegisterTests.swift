@testable import App
import Fluent
import XCTVapor
import Crypto

final class RegisterTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    let registerPath = "v1/auth/register"
    
    override func setUpWithError() throws {
        app = Application(.testing)
        try configure(app)
        self.testWorld = try TestWorld(app: app)
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testRegisterHappyPath() async throws {
        app.randomGenerators.use(.rigged(value: "token"))
        
        let data = RegisterRequest(fullName: "Test User", email: "test@test.com", password: "password123", confirmPassword: "password123")
        
        try await app.test(.POST, registerPath) { req in
            try req.content.encode(data)
        } afterResponse: { res in
            XCTAssertEqual(res.status, .created)
            let user = try await app.repositories.users.find(email: "test@test.com")
            let foundUser = try XCTUnwrap(user)
            XCTAssertEqual(foundUser.isAdmin, false)
            XCTAssertEqual(foundUser.fullName, "Test User")
            XCTAssertEqual(foundUser.email, "test@test.com")
            XCTAssertEqual(foundUser.isEmailVerified, false)
            XCTAssertTrue(try BCryptDigest().verify("password123", created: foundUser.passwordHash))
            
            let emailToken = try await app.repositories.emailTokens.find(token: SHA256.hash("token"))
            XCTAssertEqual(emailToken?.$user.id, foundUser.id)
            XCTAssertNotNil(emailToken)
            
            let job = try XCTUnwrap(app.queues.test.first(EmailJob.self))
            XCTAssertEqual(job.recipient, "test@test.com")
            XCTAssertEqual(job.email.templateName, "email_verification")
            XCTAssertEqual(job.email.templateData["verify_url"], "http://api.local/auth/email-verification?token=token")
        }
    }
    
    func testRegisterFailsWithNonMatchingPasswords() async throws {
        let data = RegisterRequest(fullName: "Test User", email: "test@test.com", password: "12345678", confirmPassword: "124")
        
        try await app.test(.POST, registerPath, beforeRequest: { request in
            try request.content.encode(data)
        }, afterResponse: { res in
            XCTAssertResponseError(res, AuthenticationError.passwordsDontMatch)
            let usersCount = try await app.repositories.users.count()
            XCTAssertEqual(usersCount, 0)
        })
    }
    
    func testRegisterFailsWithExistingEmail() throws {
        try app.autoMigrate().wait()
        defer { try! app.autoRevert().wait() }

        app.repositories.use(.database)
        
        let user = User(fullName: "Test user 1", email: "test@test.com", passwordHash: "123")
        try user.create(on: app.db).wait()
                
        let registerRequest = RegisterRequest(fullName: "Test user 2", email: "test@test.com", password: "password123", confirmPassword: "password123")
        try app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(registerRequest)
        }, afterResponse: { res in
            XCTAssertResponseError(res, AuthenticationError.emailAlreadyExists)
            let users = try User.query(on: app.db).all().wait()
            XCTAssertEqual(users.count, 1)
        })
    }
}

