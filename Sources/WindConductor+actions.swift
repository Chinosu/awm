import AppKit

extension WC {
    func raiseAction(index: Int) async {
        await prune()
        guard canon.indices.contains(index) else { return }
        info("raise")

        await raise(wind: canon[index])
        recent.append(recent.remove(at: recent.lastIndex(of: canon[index])!))

        await debug()
    }

    func prevAction() async {
        await prune()
        info("prev")

        if recent.count < 2 { return }
        let w = recent.remove(at: recent.count - 2)
        await raise(wind: w)
        recent.append(w)

        await debug()
    }

    func reorderAction(index: Int) async {
        await prune()
        info("reorder")

        if recent.isEmpty { return }

        assert(canon.contains(recent.last!))
        canon.insert(canon.remove(at: canon.lastIndex(of: recent.last!)!), at: index)
    }

    func leftAction() async {
        await prune()
        info("left")

        if recent.isEmpty { return }

        let i = canon.lastIndex(of: recent.last!)!
        let w = canon[(i - 1 + canon.count) % canon.count]
        await raise(wind: w)
        recent.append(recent.remove(at: recent.lastIndex(of: w)!))
    }

    func rightAction() async {
        await prune()
        info("right")

        if recent.isEmpty { return }

        let i = canon.lastIndex(of: recent.last!)!
        let w = canon[(i + 1) % canon.count]
        await raise(wind: w)
        recent.append(recent.remove(at: recent.lastIndex(of: w)!))
    }
}
