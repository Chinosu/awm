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

        assert(!recent.isEmpty)
        assert(canon.contains(recent.last!))
        canon.insert(canon.remove(at: canon.lastIndex(of: recent.last!)!), at: index)
    }
}
