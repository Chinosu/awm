extension LinkedSet: BidirectionalCollection {
    struct Index: Comparable {
        let i: Int?
        let mem: ArraySlice<Node>

        static func < (lhs: Index, rhs: Index) -> Bool {
            guard let r = rhs.i else { return true }
            guard let l = lhs.i else { return false }

            var cur = l
            while cur != r {
                guard let next = lhs.mem[cur].next else { return false }
                cur = next
            }

            return true
        }

        static func == (lhs: Index, rhs: Index) -> Bool {
            return lhs.i == rhs.i
        }
    }

    var startIndex: Index { Index(i: self.start, mem: self.mem[...]) }
    var endIndex: Index { Index(i: nil, mem: self.mem[...]) }

    subscript(position: Index) -> Element {
        guard let i = position.i else { preconditionFailure() }
        return self.mem[i].elem
    }

    subscript(position: Int) -> Element {
        precondition(position < self.count)

        if position <= self.count / 2 {
            var count = 0
            var i = self.start!
            while count < position {
                i = self.mem[i].next!
                count += 1
            }
            return self.mem[i].elem
        } else {
            var count = self.count - 1
            var i = self.end!
            while count > position {
                i = self.mem[i].prev!
                count -= 1
            }
            return self.mem[i].elem
        }
    }

    func index(after i: Index) -> Index {
        guard let ii = i.i else { preconditionFailure() }
        return Index(i: self.mem[ii].next, mem: self.mem[...])
    }

    func index(before i: Index) -> Index {
        if let ii = i.i {
            return Index(i: self.mem[ii].prev, mem: self.mem[...])
        } else {
            return Index(i: self.end!, mem: self.mem[...])
        }
    }
}
