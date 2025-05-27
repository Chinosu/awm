extension LinkedSet {
    mutating func alloc(elem: Element, prev: Int?, next: Int?) -> Int {
        if let i = self.free.popLast() {
            self.mem[i].elem = elem
            self.mem[i].prev = prev
            self.mem[i].next = next
            self.items[elem] = i
            return i
        }

        self.mem.append(Node(elem: elem, prev: prev, next: next))
        self.items[elem] = self.mem.count - 1
        return self.mem.count - 1
    }

    mutating func dealloc(index: Int) {
        let result = self.items.removeValue(forKey: self.mem[index].elem)
        assert(result != nil)
        self.free.append(index)
    }

    struct Node: Equatable {
        var elem: Element
        var prev: Int?
        var next: Int?
    }
}
