import Foundation
import XCTest
@testable import DiverKit

final class RouteModelTests: XCTestCase {
    func testKebabCasesNames() {
        XCTAssertEqual(RouteBuilder.kebabCase("Home"), "home")
        XCTAssertEqual(RouteBuilder.kebabCase("ProductDetails"), "product-details")
        XCTAssertEqual(RouteBuilder.kebabCase("userId"), "user-id")
        XCTAssertEqual(RouteBuilder.kebabCase("HTMLParser"), "html-parser")
    }

    func testTypeMapping() {
        XCTAssertEqual(RouteBuilder.diverType(.nominal("String")), "string")
        XCTAssertEqual(RouteBuilder.diverType(.nominal("Int")), "string")
        XCTAssertEqual(RouteBuilder.diverType(.nominal("Bool")), "boolean")
        XCTAssertEqual(RouteBuilder.diverType(.nominal("Tab")), "string") // unknown -> string
        XCTAssertEqual(RouteBuilder.diverType(.array), "list")
        XCTAssertNil(RouteBuilder.diverType(.unsupported))
    }

    func testObjectRouteHasHostOnly() {
        let route = RouteBuilder.build(simpleName: "Home", name: "", description: "", params: [])!
        XCTAssertEqual(route.host, "home")
        XCTAssertEqual(route.path, "")
        XCTAssertTrue(route.query.isEmpty)
        XCTAssertEqual(route.name, "home") // falls back to host
    }

    func testRequiredBecomePathOptionalBecomeQuery() {
        let route = RouteBuilder.build(
            simpleName: "ProductDetails",
            name: "",
            description: "",
            params: [
                ParamInfo(name: "id", type: "string", optional: false),
                ParamInfo(name: "ref", type: "string", optional: true),
            ]
        )!
        XCTAssertEqual(route.host, "product-details")
        XCTAssertEqual(route.path, ":id")
        XCTAssertEqual(route.query, [QueryParam(name: "ref", type: "string")])
        XCTAssertEqual(route.name, "product-details/:id")
    }

    func testMetadataNameOverridesFallback() {
        let route = RouteBuilder.build(
            simpleName: "Settings",
            name: "Settings",
            description: "App settings",
            params: [ParamInfo(name: "tab", type: "string", optional: true)]
        )!
        XCTAssertEqual(route.name, "Settings")
        XCTAssertEqual(route.description, "App settings")
        XCTAssertEqual(route.path, "")
        XCTAssertEqual(route.query, [QueryParam(name: "tab", type: "string")])
    }

    func testNonDeeplinkSafeRouteIsSkipped() {
        let route = RouteBuilder.build(
            simpleName: "Detail",
            name: "",
            description: "",
            params: [ParamInfo(name: "action", type: nil, optional: false)]
        )
        XCTAssertNil(route)
    }

    func testEncodeSortsDedupesAndMatchesSchema() throws {
        let routes = [
            RouteModel(name: "Settings", description: "App settings", host: "settings", path: "",
                       query: [QueryParam(name: "tab", type: "string")]),
            RouteModel(name: "home", description: "", host: "home", path: "", query: []),
            RouteModel(name: "dup", description: "", host: "home", path: "", query: []),
        ]
        let data = Data(RouteJSON.encode(routes).utf8)
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let array = root["routes"] as! [[String: Any]]

        XCTAssertEqual(array.count, 2) // duplicate host+path dropped
        XCTAssertEqual(array[0]["host"] as? String, "home") // sorted by host
        XCTAssertEqual(array[1]["host"] as? String, "settings")

        let settings = array[1]
        XCTAssertEqual(settings["name"] as? String, "Settings")
        XCTAssertEqual(settings["description"] as? String, "App settings")
        let query = settings["query"] as! [[String: Any]]
        XCTAssertEqual(query[0]["name"] as? String, "tab")
        XCTAssertEqual(query[0]["type"] as? String, "string")
    }
}
