import Foundation

@main
struct JSONSourceEditTests {
    static func main() throws {
        let source = "{\n  \"emoji😀\": \"中文\\n😀\", \"project\": {\"id\":9007199254740993},\n  \"id\": 254136, \"other\":1.2300e+04, \"items\":[true,{\"id\":2}], \"a.b\":3, \"a\":{\"b\":4}\n}"
        let map = try JSONSourceMap(source)
        let number = try map.edit(path: ["root", "id"], key: false, input: "254137", type: .number)
        check(try number.applying(to: source) == source.replacingOccurrences(of: "254136", with: "254137"))
        let rename = try map.edit(path: ["root", "project", "id"], key: true, input: "new\"name😀", type: .string)
        let renamed = try rename.applying(to: source)
        precondition(renamed == source.replacingOccurrences(of: "\"id\":9007199254740993", with: "\"new\\\"name😀\":9007199254740993"))
        let array = try map.edit(path: ["root", "items", "[1]", "id"], key: false, input: "null", type: .null)
        check(try array.applying(to: source) == source.replacingOccurrences(of: "\"id\":2", with: "\"id\":null"))
        let dotted = try map.edit(path: ["root", "a.b"], key: false, input: "5", type: .number)
        check(try dotted.applying(to: source) == source.replacingOccurrences(of: "\"a.b\":3", with: "\"a.b\":5"))
        let string = try map.edit(path: ["root", "emoji😀"], key: false, input: "new\n\"text\"\\", type: .string)
        let changed = try JSONSerialization.jsonObject(with: Data(string.applying(to: source).utf8)) as! [String: Any]
        precondition(changed["emoji😀"] as? String == "new\n\"text\"\\")
        let originalEscaping = #"{"\u0061":"\u0062"}"#
        let escaped = try JSONSourceMap(originalEscaping)
        check(try escaped.edit(path: ["root", "a"], key: true, input: "a", type: .string).applying(to: originalEscaping) == originalEscaping)
        check(try escaped.edit(path: ["root", "a"], key: false, input: "b", type: .string).applying(to: originalEscaping) == originalEscaping)
        for input in ["NaN", "Infinity", "01", "1.", "1,\"injected\":2", " 1", "1\n"] {
            expectFailure { _ = try map.edit(path: ["root", "id"], key: false, input: input, type: .number) }
        }
        expectFailure { _ = try map.edit(path: ["root", "id"], key: true, input: "project", type: .string) }
        expectFailure { _ = try map.edit(path: ["root", "items"], key: false, input: "1", type: .number) }
        expectFailure { _ = try map.edit(path: ["root", "items", "[0]"], key: true, input: "x", type: .string) }
        expectFailure { _ = try map.edit(path: ["root", "missing"], key: false, input: "1", type: .number) }
        expectFailure { _ = try number.applying(to: source + " ") }
        expectFailure { _ = try JSONSourceMap(#"{"a":1,"\u0061":2}"#) }
        expectFailure { _ = try JSONSourceMap(#"{"a":"#) }
        print("JSON source edit regressions passed")
    }

    static func check(_ condition: Bool) { precondition(condition) }

    static func expectFailure(_ work: () throws -> Void) {
        do { try work(); fatalError("Expected edit rejection") }
        catch { }
    }
}
