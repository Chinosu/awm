import Testing

@testable import awm

@Suite struct `LinkedSet Tests` {
    @Test func `monolith test`() async throws {
        var ls = LinkedSet<String>()

        ls.append("first")
        ls.append("second")
        ls.append("third")

        do {
            #expect(ls.count == 3)
            #expect(ls.first == "first")
            #expect(ls.last == "third")
            #expect(ls.items == ["first": 0, "second": 1, "third": 2])
            #expect(
                ls.mem == [
                    LinkedSet.Node(elem: "first", prev: nil, next: 1),
                    LinkedSet.Node(elem: "second", prev: 0, next: 2),
                    LinkedSet.Node(elem: "third", prev: 1, next: nil),
                ])
            #expect(ls.free == [])
            #expect(ls.map(\.self) == ["first", "second", "third"])
        }

        ls.reappend("first")

        do {
            #expect(ls.count == 3)
            #expect(ls.first == "second")
            #expect(ls.last == "first")
            #expect(ls.items == ["first": 0, "second": 1, "third": 2])
            #expect(
                ls.mem == [
                    LinkedSet.Node(elem: "first", prev: 2, next: nil),
                    LinkedSet.Node(elem: "second", prev: nil, next: 2),
                    LinkedSet.Node(elem: "third", prev: 1, next: 0),
                ])
            #expect(ls.free == [])
            #expect(ls.map(\.self) == ["second", "third", "first"])
        }

        ls.delete("third")

        do {
            #expect(ls.count == 2)
            #expect(ls.first == "second")
            #expect(ls.last == "first")
            #expect(ls.items == ["first": 0, "second": 1])
            #expect(
                ls.mem == [
                    LinkedSet.Node(elem: "first", prev: 1, next: nil),
                    LinkedSet.Node(elem: "second", prev: nil, next: 0),
                    LinkedSet.Node(elem: "third", prev: 1, next: 0),
                ])
            #expect(ls.free == [2])
            #expect(ls.map(\.self) == ["second", "first"])
        }

        ls.reappend("fourth")

        do {
            #expect(ls.count == 3)
            #expect(ls.first == "second")
            #expect(ls.last == "fourth")
            #expect(ls.items == ["first": 0, "second": 1, "fourth": 2])
            #expect(
                ls.mem == [
                    LinkedSet.Node(elem: "first", prev: 1, next: 2),
                    LinkedSet.Node(elem: "second", prev: nil, next: 0),
                    LinkedSet.Node(elem: "fourth", prev: 0, next: nil),
                ])
            #expect(ls.free == [])
            #expect(ls.map(\.self) == ["second", "first", "fourth"])
        }

        ls.delete("first")
        ls.delete("second")
        ls.delete("fourth")

        do {
            #expect(ls.count == 0)
            #expect(ls.first == nil)
            #expect(ls.last == nil)
            #expect(ls.items == [:])
            #expect(
                ls.mem == [
                    LinkedSet.Node(elem: "first", prev: 1, next: 2),
                    LinkedSet.Node(elem: "second", prev: nil, next: 2),
                    LinkedSet.Node(elem: "fourth", prev: nil, next: nil),
                ])
            #expect(ls.free == [0, 1, 2])
            #expect(ls.map(\.self) == [])
        }

        ls = ["hi", "hello", "bye"]

        do {
            #expect(ls.count == 3)
            #expect(ls.first == "hi")
            #expect(ls.last == "bye")
            #expect(ls.items == ["hi": 0, "hello": 1, "bye": 2])
            #expect(
                ls.mem == [
                    LinkedSet.Node(elem: "hi", prev: nil, next: 1),
                    LinkedSet.Node(elem: "hello", prev: 0, next: 2),
                    LinkedSet.Node(elem: "bye", prev: 1, next: nil),
                ])
            #expect(ls.free == [])
            #expect(ls.map(\.self) == ["hi", "hello", "bye"])
        }

        ls.reappend("yeti")
        ls.delete(where: { $0.count & 1 == 0 })

        do {
            #expect(ls.count == 2)
            #expect(ls.first == "hello")
            #expect(ls.last == "bye")
            #expect(ls.items == ["hello": 1, "bye": 2])
            #expect(
                ls.mem == [
                    LinkedSet.Node(elem: "hi", prev: nil, next: 1),
                    LinkedSet.Node(elem: "hello", prev: nil, next: 2),
                    LinkedSet.Node(elem: "bye", prev: 1, next: nil),
                    LinkedSet.Node(elem: "yeti", prev: 2, next: nil),
                ])
            #expect(ls.free == [0, 3])
            #expect(ls.map(\.self) == ["hello", "bye"])
        }

        ls.reinsert(at: 0, "zero")
        ls.reinsert(at: 2, "two")
        ls.reinsert(at: 100, "end")

        do {
            #expect(ls.count == 5)
            #expect(ls.first == "zero")
            #expect(ls.last == "end")
            #expect(ls.items == ["zero": 3, "hello": 1, "bye": 2, "two": 0, "end": 4])
            #expect(
                ls.mem == [
                    LinkedSet.Node(elem: "two", prev: 1, next: 2),
                    LinkedSet.Node(elem: "hello", prev: 3, next: 0),
                    LinkedSet.Node(elem: "bye", prev: 0, next: 4),
                    LinkedSet.Node(elem: "zero", prev: nil, next: 1),
                    LinkedSet.Node(elem: "end", prev: 2, next: nil),
                ])
            #expect(ls.free == [])
            #expect(ls.map(\.self) == ["zero", "hello", "two", "bye", "end"])
        }
    }
}
