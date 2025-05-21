extension LinkedSet: Sequence {
    func makeIterator() -> Iterator {
        return Iterator(index: self.start, mem: self.mem)
    }

    struct Iterator: IteratorProtocol {
        var index: Int?
        let mem: [Node]

        mutating func next() -> Element? {
            guard let i = self.index else { return nil }
            let node = self.mem[i]
            self.index = node.next
            return node.elem
        }
    }
}
