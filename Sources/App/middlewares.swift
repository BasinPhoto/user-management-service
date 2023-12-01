import Vapor

func middlewares(_ app: Application) throws {
    // Remove all existing middleware.
    app.middleware = .init()

    app.middleware.use(
        FileMiddleware(
            publicDirectory: app.directory.publicDirectory,
            defaultFile: "index.html"
        )
    )
    
    app.middleware.use(ErrorMiddleware.custom(environment: app.environment))
}
