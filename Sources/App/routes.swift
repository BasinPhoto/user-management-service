import Fluent
import Vapor

func routes(_ app: Application) throws {
    let root = app.grouped("api")
    let auth = root.grouped("auth")
    let swagger = app.grouped("swagger")
    
    try auth.register(collection: AuthenticationController())
    try swagger.register(collection: SwaggerController())
}
