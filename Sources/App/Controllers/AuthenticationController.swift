import Vapor
import Fluent
import VaporToOpenAPI

struct AuthenticationController: RouteCollection {
    let tag = TagObject(
        name: "Authentication Controller",
        description:
        """
        Controller responsible for user authentication, registering, logout and so on.
        """
    )

    func boot(routes: RoutesBuilder) throws {
        routes.post("register", use: register)
            .openAPI(
                tags: tag,
                summary: "User registering",
                description: "Register user by email",
                body: .type(of: RegisterRequest.example),
                contentType: .application(.json)
            )
            .response(statusCode: .noContent, description: "Successfully registered. No content.")
            .response(statusCode: .badRequest, description: "Bad request")
        
        routes.post("login", use: login)
        
        routes.group("email-verification") { emailVerificationRoutes in
            emailVerificationRoutes.post("", use: sendEmailVerification)
            emailVerificationRoutes.get("", use: verifyEmail)
        }
        
        routes.group("reset-password") { resetPasswordRoutes in
            resetPasswordRoutes.post("", use: resetPassword)
            resetPasswordRoutes.get("verify", use: verifyResetPasswordToken)
        }
        routes.post("recover", use: recoverAccount)
        
        routes.post("accessToken", use: refreshAccessToken)
        
        // Authentication required
        routes.group(UserAuthenticator()) { authenticated in
            authenticated.get("me", use: getCurrentUser)
        }
    }
    
    private func register(_ req: Request) async throws -> HTTPStatus {
        try RegisterRequest.validate(content: req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        guard registerRequest.password == registerRequest.confirmPassword else {
            throw AuthenticationError.passwordsDontMatch
        }
        
        let passwordHash = try await req.password.async.hash(registerRequest.password)
        let user = try User(from: registerRequest, hash: passwordHash)
        try await req.users.create(user)
        try await req.emailVerifier.verify(for: user)
        
        return HTTPStatus.created        
    }
    
    private func login(_ req: Request) async throws -> LoginResponse {
        try LoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(LoginRequest.self)
        
        let user = try await req.users.find(email: loginRequest.email)
        
        guard let user else {
            throw AuthenticationError.invalidEmailOrPassword
        }
        
        guard user.isEmailVerified else {
            throw AuthenticationError.emailIsNotVerified
        }
        
        let checkPassed = try await req.password.async
            .verify(loginRequest.password, created: user.passwordHash)
        
        guard checkPassed else {
            throw AuthenticationError.invalidEmailOrPassword
        }
        
        try await req.refreshTokens.delete(for: user.requireID())
        
        let token = req.random.generate(bits: 256)
        let refreshToken = try RefreshToken(token: SHA256.hash(token), userID: user.requireID())
        try await req.refreshTokens.create(refreshToken)
        
        return try LoginResponse(
            user: UserDTO(from: user),
            accessToken: req.jwt.sign(Payload(with: user)),
            refreshToken: token
        )
    }
    
    private func refreshAccessToken(_ req: Request) async throws -> AccessTokenResponse {
        let accessTokenRequest = try req.content.decode(AccessTokenRequest.self)
        let hashedRefreshToken = SHA256.hash(accessTokenRequest.refreshToken)
        
        guard let refreshToken = try await req.refreshTokens.find(token: hashedRefreshToken) else {
            throw AuthenticationError.refreshTokenOrUserNotFound
        }
        
        try await req.refreshTokens.delete(refreshToken)
        guard refreshToken.expiresAt > Date() else {
            throw AuthenticationError.refreshTokenHasExpired
        }
        
        guard let user = try await req.users.find(id: refreshToken.$user.id) else {
            throw AuthenticationError.refreshTokenOrUserNotFound
        }
        
        let token = req.random.generate(bits: 256)
        let newRefreshToken = try RefreshToken(token: SHA256.hash(token), userID: user.requireID())
        
        let payload = try Payload(with: user)
        let accessToken = try req.jwt.sign(payload)
        
        try await req.refreshTokens.create(newRefreshToken)
        return AccessTokenResponse(refreshToken: token, accessToken: accessToken)
    }
    
    private func getCurrentUser(_ req: Request) async throws -> UserDTO {
        let payload = try req.auth.require(Payload.self)
        
        guard let user = try await req.users.find(id: payload.userID) else {
            throw AuthenticationError.userNotFound
        }
        
        return UserDTO(from: user)
    }
    
    private func verifyEmail(_ req: Request) async throws -> HTTPStatus {
        let token = try req.query.get(String.self, at: "token")
        let hashedToken = SHA256.hash(token)
        
        guard let emailToken = try await req.emailTokens.find(token: hashedToken) else {
            throw AuthenticationError.emailTokenNotFound
        }
        
        guard emailToken.expiresAt > Date.now else {
            throw AuthenticationError.emailTokenHasExpired
        }
        
        try await req.emailTokens.delete(emailToken)
        try await req.users.set(\.$isEmailVerified, to: true, for: emailToken.$user.id)
        
        return .ok
    }
    
    private func resetPassword(_ req: Request) async throws -> HTTPStatus {
        let resetPasswordRequest = try req.content.decode(ResetPasswordRequest.self)
        guard let user = try await req.users.find(email: resetPasswordRequest.email) else {
            return .noContent
        }
        try await req.passwordResetter.reset(for: user)
        return .noContent
    }
    
    private func verifyResetPasswordToken(_ req: Request) async throws -> HTTPStatus {
        let token = try req.query.get(String.self, at: "token")
        
        let hashedToken = SHA256.hash(token)
        
        guard let passwordToken = try await req.passwordTokens.find(token: hashedToken) else {
            throw AuthenticationError.invalidPasswordToken
        }
        
        guard passwordToken.expiresAt > Date.now else {
            try await req.passwordTokens.delete(passwordToken)
            throw AuthenticationError.passwordTokenHasExpired
        }
        
        return .noContent
    }
    
    private func recoverAccount(_ req: Request) async throws -> HTTPStatus {
        try RecoverAccountRequest.validate(content: req)
        let content = try req.content.decode(RecoverAccountRequest.self)
        
        guard content.password == content.confirmPassword else {
            throw AuthenticationError.passwordsDontMatch
        }
        
        let hashedToken = SHA256.hash(content.token)
        guard let passwordToken = try await req.passwordTokens.find(token: hashedToken) else {
            throw AuthenticationError.invalidPasswordToken
        }
        
        guard passwordToken.expiresAt > Date() else {
            try await req.passwordTokens.delete(passwordToken)
            throw AuthenticationError.passwordTokenHasExpired
        }
        
        let digest = try await req.password.async.hash(content.password)
        try await req.users.set(\.$passwordHash, to: digest, for: passwordToken.$user.id)
        try await req.passwordTokens.delete(for: passwordToken.$user.id)
        
        return .noContent
    }
    
    private func sendEmailVerification(_ req: Request) async throws -> HTTPStatus {
        let content = try req.content.decode(SendEmailVerificationRequest.self)
        
        guard let user = try await req.users.find(email: content.email), !user.isEmailVerified else {
            return .noContent
        }
        
        try await req.emailVerifier.verify(for: user)
        return .noContent
    }
}
