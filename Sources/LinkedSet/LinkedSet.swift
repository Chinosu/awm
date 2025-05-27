struct LinkedSet<Element> where Element: Hashable {
    var items: [Element: Int] = [:]
    var start: Int? = nil
    var end: Int? = nil

    var mem: [Node] = []
    var free: Set<Int> = []

    var count: Int { self.items.count }

    mutating func append(_ item: Element) {
        guard self.items[item] == nil else { return }

        guard !self.items.isEmpty else {
            let cur = self.alloc(elem: item, prev: nil, next: nil)
            self.start = cur
            self.end = cur
            return
        }

        let cur = self.alloc(elem: item, prev: self.end, next: nil)
        self.mem[self.end!].next = cur
        self.end = cur
    }

    mutating func reappend(_ item: Element) {
        if self.items[item] != nil { self.delete(item) }
        self.append(item)
    }

    mutating func reinsert(at index: Int, _ item: Element) {
        if self.items[item] != nil { self.delete(item) }

        if self.items.isEmpty {
            let cur = self.alloc(elem: item, prev: nil, next: nil)
            self.start = cur
            self.end = cur
            return
        }

        if index == 0 {
            let node = self.alloc(elem: item, prev: nil, next: self.start)
            self.start = node
            return
        }

        var count = 1
        var cur: Int! = self.start
        while self.mem[cur].next != nil && count < index {
            cur = self.mem[cur].next
            count += 1
        }

        let node = self.alloc(elem: item, prev: cur, next: self.mem[cur].next)
        if let next = self.mem[cur].next {
            self.mem[next].prev = node
        } else {
            self.end = node
        }
        self.mem[cur].next = node
    }

    mutating func delete(_ item: Element) {
        guard let cur = self.items[item] else { return }

        if let prev = self.mem[cur].prev {
            self.mem[prev].next = self.mem[cur].next
        } else {
            self.start = self.mem[cur].next
        }

        if let next = self.mem[cur].next {
            self.mem[next].prev = self.mem[cur].prev
        } else {
            self.end = self.mem[cur].prev
        }

        self.dealloc(index: cur)
    }

    mutating func delete(where: (Element) -> Bool) {
        var cur = self.start
        while let c = cur {
            let node = self.mem[c]
            if `where`(node.elem) {
                if let prev = node.prev {
                    self.mem[prev].next = node.next
                } else {
                    self.start = node.next
                }

                if let next = node.next {
                    self.mem[next].prev = node.prev
                } else {
                    self.end = node.prev
                }

                self.dealloc(index: c)
            }

            cur = node.next
        }
    }

    // mutating func updateEach(_ update: (inout Element) -> Void) {
    //     for i in self.mem.indices {
    //         if self.free.contains(i) { continue }
    //         update(&self.mem[i].elem)
    //     }
    // }

    mutating func alloc(elem: Element, prev: Int?, next: Int?) -> Int {
        if let i = self.free.first {
            self.free.remove(i)
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
        self.free.insert(index)
    }

    struct Node {
        var elem: Element
        var prev: Int?
        var next: Int?
    }
}
