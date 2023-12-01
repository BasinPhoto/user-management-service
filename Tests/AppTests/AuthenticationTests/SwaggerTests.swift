@testable import App
import XCTVapor

final class SwaggerTests: XCTestCase {
    var app: Application!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.app = Application(.testing)
        try configure(self.app)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.app.shutdown()
    }
    
    func testGetSwagger() throws {
        try self.app.test(.GET, "swagger/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNotNil(res.content)
            XCTAssertNotNil(res.body.string)
            let contentType = try XCTUnwrap(res.headers.contentType)
            XCTAssertEqual(contentType, .html)
        }
    }

    func testGetSwaggerJson() throws {
        try self.app.test(.GET, "swagger/swagger.json") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNotNil(res.content)
            XCTAssertNotNil(res.body.string)
            let contentType = try XCTUnwrap(res.headers.contentType)
            XCTAssertEqual(contentType, .json)
        }
    }
}
