struct LinkedSet<Element> where Element: Hashable {
    var items: [Element: Int] = [:]
    var start: Int? = nil
    var end: Int? = nil

    var mem: [Node] = []
    var free: Set<Int> = []

    mutating func append(_ item: Element, deleteExisting: Bool = true) {
        if nil != self.items[item] {
            if !deleteExisting { return }
            self.delete(item)
        }

        if self.items.isEmpty {
            let cur = self.alloc(elem: item, prev: nil, next: nil)
            self.start = cur
            self.end = cur
            self.items[item] = cur
            return
        }

        let cur = self.alloc(elem: item, prev: self.end, next: nil)
        self.mem[self.end!].next = cur
        self.end = cur
        self.items[item] = cur
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

        self.items.removeValue(forKey: item)
        self.dealloc(index: cur)
    }

    mutating func alloc(elem: Element, prev: Int?, next: Int?) -> Int {
        if let i = self.free.first {
            self.free.remove(i)
            self.mem[i].elem = elem
            self.mem[i].prev = prev
            self.mem[i].next = next
            return i
        }

        self.mem.append(Node(elem: elem, prev: prev, next: next))
        return self.mem.count - 1
    }

    mutating func dealloc(index: Int) {
        self.free.insert(index)
    }

    struct Node {
        var elem: Element
        var prev: Int?
        var next: Int?
    }
}
