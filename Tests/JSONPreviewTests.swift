import Foundation

@main
struct JSONPreviewTests {
    static func main() throws {
        let source = #"{"project":{"id":9007199254740993,"name":"Needle\n\"quoted\""},"array":[1,{"active":true}],"empty":{},"a.b":2,"a":{"b":3}}"#
        let nodes = try JSONParser.parse(Data(source.utf8))
        let collapsed = JSONPreviewDocument(nodes: nodes, expandedPaths: [["root"]], query: "")
        precondition(collapsed.rows.contains { $0.key == "project" && $0.text == "{…}" })
        precondition(!collapsed.rows.contains { $0.key == "id" })
        precondition(collapsed.rows.contains { $0.key == "empty" && $0.text == "{}" && !$0.expandable })

        let full = JSONPreviewDocument(nodes: nodes, expandedPaths: collapsed.containerPaths, query: "")
        let rendered = full.rows.map { row in
            (row.key.map { JSONPreviewDocument.quote($0) + ": " } ?? "") + row.text + (row.comma ? "," : "")
        }.joined(separator: "\n")
        // Fully expanded rows must still represent the same JSON, with proper escaping and commas.
        let original = try JSONSerialization.jsonObject(with: Data(source.utf8)) as! NSDictionary
        let roundTrip = try JSONSerialization.jsonObject(with: Data(rendered.utf8)) as! NSDictionary
        precondition(original == roundTrip)
        precondition(full.rows.contains { $0.key == "id" && $0.text == "9007199254740993" })
        precondition(Set(full.rows.map(\.id)).count == full.rows.count, "Paths containing dots must not collide")

        let searched = JSONPreviewDocument(nodes: nodes, expandedPaths: [], query: "needle")
        precondition(searched.matchIDs.count == 1)
        precondition(searched.rows.contains { $0.key == "project" && $0.expanded })
        precondition(searched.rows.contains { $0.key == "name" && $0.matches })
        let numberSearch = JSONPreviewDocument(nodes: nodes, expandedPaths: [], query: "9007199254740993")
        precondition(numberSearch.matchIDs.count == 1)
        let arraySearch = JSONPreviewDocument(nodes: nodes, expandedPaths: [], query: "true")
        precondition(arraySearch.matchIDs.count == 1)
        precondition(arraySearch.rows.contains { $0.key == "active" && $0.matches })
        precondition(JSONPreviewDocument(nodes: nodes, expandedPaths: [], query: "[0]").matchIDs.isEmpty)
        precondition(JSONPreviewDocument(nodes: nodes, expandedPaths: [], query: "missing").matchIDs.isEmpty)
        precondition(JSONPreviewDocument(nodes: nodes, expandedPaths: [], query: "").rows.count == 1)
        precondition(JSONPreviewDocument(nodes: [], expandedPaths: [], query: "needle").rows.isEmpty)
        print("JSON preview regressions passed")
    }
}
