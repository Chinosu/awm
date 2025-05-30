import AppKit

extension WC {
    func raiseAction(index: Int) async {
        await prune()
        guard canon.indices.contains(index) else { return }
        print("(raise)")

        await raise(wind: canon[index])
        recent.append(recent.remove(at: recent.lastIndex(of: canon[index])!))
    }

    func prevAction() async {
        await prune()

        if recent.count < 2 { return }
        let w = recent.remove(at: recent.count - 2)
        await raise(wind: w)
        recent.append(w)
    }
}
