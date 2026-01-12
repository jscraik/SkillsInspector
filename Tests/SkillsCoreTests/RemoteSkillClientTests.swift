import XCTest
@testable import SkillsCore

final class RemoteSkillClientTests: XCTestCase {
    override class func setUp() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override class func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
    }

    func testFetchLatestMapsFields() async throws {
        MockURLProtocol.requestHandler = { request in
            guard request.url?.path == "/api/v1/skills" else { throw URLError(.badURL) }
            let body = """
            { "items": [ { "slug": "demo", "displayName": "Demo Skill", "summary": "Sum", "updatedAt": 1700000000000, "latestVersion": { "version": "1.2.3", "createdAt": 1700000000000, "changelog": "" }, "stats": { "downloads": 10, "stars": 2 } } ] }
            """
            return (MockURLProtocol.makeResponse(for: request, statusCode: 200), body.data(using: .utf8)!)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = RemoteSkillClient.live(baseURL: URL(string: "https://mock.local")!, session: session)
        let items = try await client.fetchLatest(5)
        XCTAssertEqual(items.count, 1)
        let item = items[0]
        XCTAssertEqual(item.slug, "demo")
        XCTAssertEqual(item.latestVersion, "1.2.3")
        XCTAssertEqual(item.downloads, 10)
        XCTAssertEqual(item.stars, 2)
    }

    func testSearchMapsOptionalFields() async throws {
        MockURLProtocol.requestHandler = { request in
            guard request.url?.path == "/api/v1/search" else { throw URLError(.badURL) }
            let body = """
            { "results": [ { "slug": "s1", "displayName": "Skill 1", "summary": null, "version": "0.1.0", "updatedAt": 1700000000000 } ] }
            """
            return (MockURLProtocol.makeResponse(for: request, statusCode: 200), body.data(using: .utf8)!)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = RemoteSkillClient.live(baseURL: URL(string: "https://mock.local")!, session: session)
        let items = try await client.search("skill", 10)
        XCTAssertEqual(items.first?.slug, "s1")
        XCTAssertEqual(items.first?.latestVersion, "0.1.0")
    }

    func testFetchLatestVersion() async throws {
        MockURLProtocol.requestHandler = { request in
            guard request.url?.path == "/api/v1/skills/demo" else { throw URLError(.badURL) }
            let body = """
            { "latestVersion": { "version": "2.0.0", "createdAt": 1700000000000, "changelog": "" } }
            """
            return (MockURLProtocol.makeResponse(for: request, statusCode: 200), body.data(using: .utf8)!)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = RemoteSkillClient.live(baseURL: URL(string: "https://mock.local")!, session: session)
        let version = try await client.fetchLatestVersion("demo")
        XCTAssertEqual(version, "2.0.0")
    }
}

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeResponse(for request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
