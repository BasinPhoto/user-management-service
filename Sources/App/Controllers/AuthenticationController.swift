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
        // MARK: - Routes
        routes.post("register", use: register)
            .openAPI(
                tags: tag,
                summary: "Register",
                description: """
                Registering user by email
                Full name is required and has minimum length 3 characters
                Password has should be at least 8 symbols
                """,
                body: .type(of: RegisterRequest.example),
                contentType: .application(.json)
            )
            .response(statusCode: .noContent, description: "Successfully registered")
        
        routes.post("login", use: login)
            .openAPI(
                tags: tag,
                summary: "Login",
                description: """
                Login user by credentials
                """,
                body: .type(of: LoginRequest.example),
                contentType: .application(.json)
            )
            .response(
                body: .type(of: LoginResponse.example),
                contentType: .application(.json),
                description: "Successfully logged in"
            )

        routes.post("email-verification", use: sendEmailVerification)
            .openAPI(
                tags: tag,
                summary: "Send E-mail verification",
                description: """
                Sends email with verification link
                Token for verification expires after 24h
                """,
                body: .type(of: SendEmailVerificationRequest.example),
                contentType: .application(.json)
            )
            .response(statusCode: .noContent, description: "Email verification successfully send")
        
        routes.get("email-verification", use: verifyEmail)
            .openAPI(
                tags: tag,
                summary: "Verify E-mail",
                description: """
                For verify requested email
                Token for verification expires after 24h
                """,
                query: .type(of: TokenQuery.example)
            )
            .response(statusCode: .ok, description: "Email successfully verified")
        
        routes.post("reset-password", use: resetPassword)
            .openAPI(
                tags: tag,
                summary: "Reset password",
                description: """
                Request reset password by email
                """,
                body: .type(of: ResetPasswordRequest.example),
                contentType: .application(.json)
            )
            .response(statusCode: .noContent, description: "Successfully requested password reset")
        
        routes.get("reset-password", "verify", use: verifyResetPasswordToken)
            .openAPI(
                tags: tag,
                summary: "Reset password",
                description: """
                Reset password confirmation
                """,
                query: .type(of: TokenQuery.example)
            )
            .response(statusCode: .noContent, description: "Password successfully reseted")
        
        routes.post("recover", use: recoverAccount)
            .openAPI(
                tags: tag,
                summary: "Recover",
                description: """
                Recover account by set new password
                """,
                body: .type(of: RecoverAccountRequest.example),
                contentType: .application(.json)
            )
            .response(statusCode: .noContent, description: "Successfully requested password reset")
        
        routes.post("accessToken", use: refreshAccessToken)
            .openAPI(
                tags: tag,
                summary: "Refresh Token",
                description: """
                Recover account by set new password
                """,
                body: .type(of: RecoverAccountRequest.example),
                contentType: .application(.json)
            )
            .response(statusCode: .noContent, description: "Successfully requested password reset")
        
        // Authentication required
        routes.group(UserAuthenticator()) { authenticated in
            authenticated.get("me", use: getCurrentUser)
        }
    }
    
    // MARK: - Implementations
    
    private func register(_ req: Request) async throws -> HTTPStatus {
        try RegisterRequest.validate(content: req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        guard registerRequest.password == registerRequest.confirmPassword else {
            throw AuthenticationError.passwordsDontMatch
        }
        
        let passwordHash = try await req.password.async.hash(registerRequest.password)
        let user = try User(from: registerRequest, hash: passwordHash)
        do {
            try await req.users.create(user)
        } catch {
            if let dbError = error as? DatabaseError, dbError.isConstraintFailure {
                throw AuthenticationError.emailAlreadyExists
            } else {
                throw error                
            }
        }
        
        try await req.emailVerifier.verify(for: user)
        
        return .created
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
        try TokenQuery.validate(query: req)
        let query = try req.query.decode(TokenQuery.self)
        
        let hashedToken = SHA256.hash(query.token)
        
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
        try TokenQuery.validate(query: req)
        let query = try req.query.decode(TokenQuery.self)
        
        let hashedToken = SHA256.hash(query.token)
        
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
