import Fluent
import Vapor

func routes(_ app: Application) throws {
    let root = app.grouped("v1")
    let auth = root.grouped("auth")
    
    try auth.register(collection: AuthenticationController())
}
