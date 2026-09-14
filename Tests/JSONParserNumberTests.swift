import Foundation

// Standalone regression executable; compile together with the two model files.
@main
struct JSONParserNumberTests {
    static func main() throws {
        let data = Data(#"{"integer":31,"large":9007199254740993,"id":1826914767952347,"signedMin":-9223372036854775808,"unsignedMax":18446744073709551615,"decimal":1.25,"negative":-42,"zero":0,"enabled":true,"disabled":false,"nested":[9007199254740993,null,"9007199254740993"]}"#.utf8)
        let root = try JSONParser.parse(data)[0]
        let expected = [
            "integer": "31", "large": "9007199254740993",
            "id": "1826914767952347", "signedMin": "-9223372036854775808",
            "unsignedMax": "18446744073709551615", "decimal": "1.25",
            "negative": "-42", "zero": "0"
        ]
        for (key, text) in expected {
            let node = root.children.first { $0.key == key }!
            guard case .number = node.value else { fatalError("Not a number: \(key)") }
            precondition(node.displayValue == text, "\(key): expected \(text), got \(node.displayValue)")
        }
        for (key, expected) in [("enabled", true), ("disabled", false)] {
            let node = root.children.first { $0.key == key }!
            guard case .bool(let value) = node.value else { fatalError("Not a boolean: \(key)") }
            precondition(value == expected)
        }
        let nested = root.children.first { $0.key == "nested" }!.children
        precondition(nested[0].displayValue == "9007199254740993")
        precondition(nested[1].displayValue == "null")
        precondition(nested[2].displayValue == #""9007199254740993""#)
        print("JSON parser number regressions passed")
    }
}
