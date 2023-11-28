import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import Mailgun
import QueuesRedisDriver

public func configure(_ app: Application) throws {
    // MARK: JWT
    if app.environment != .testing {
        let jwksFilePath = app.directory.workingDirectory + (Environment.get("JWKS_KEYPAIR_FILE") ?? "keypair.jwks")
         guard
             let jwks = FileManager.default.contents(atPath: jwksFilePath),
             let jwksString = String(data: jwks, encoding: .utf8)
             else {
                 fatalError("Failed to load JWKS Keypair file at: \(jwksFilePath)")
         }
         try app.jwt.signers.use(jwksJSON: jwksString)
    }
    
    // MARK: Database
    let databasePort: Int
    let databaseLocalhost: String
    let databaseUsername: String
    let databasePassword: String
    let databaseName: String
    // 1
    if (app.environment == .testing) {
        databaseLocalhost = "localhost"
        databaseUsername = "vapor_username"
        databasePassword = "vapor_password"
        databaseName = "vapor-test"
        databasePort = 5433
    } else {
        databaseLocalhost = Environment.get("DATABASE_HOST") ?? "localhost"
        databaseUsername = Environment.get("DATABASE_USERNAME") ?? "vapor"
        databasePassword = Environment.get("DATABASE_PASSWORD") ?? "password"
        databaseName = Environment.get("DATABASE_NAME") ?? "vapor"
        databasePort = 5432
    }
    
    // Configure PostgreSQL database
    let postgresConfiguration = SQLPostgresConfiguration(
        hostname: databaseLocalhost,
        port: databasePort,
        username: databaseUsername,
        password: databasePassword,
        database: databaseName,
        tls: .disable
    )
    
    app.databases.use(.postgres(configuration: postgresConfiguration), as: .psql)
        
    // MARK: Middleware
    app.middleware = .init()
    app.middleware.use(ErrorMiddleware.custom(environment: app.environment))
    
    // MARK: Model Middleware
    
    // MARK: Mailgun
    app.mailgun.configuration = .environment
    app.mailgun.defaultDomain = .sandbox
    
    // MARK: App Config
    app.config = .environment
    
    try routes(app)
    try migrations(app)
    try queues(app)
    try services(app)
    
    
    if app.environment == .development {
        try app.autoMigrate().wait()
        try app.queues.startInProcessJobs()
    }
}
