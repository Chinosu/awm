extension LinkedSet: ExpressibleByArrayLiteral {
    typealias ArrayLiteralElement = Element

    init(arrayLiteral elements: Element...) {
        // assume: deleteExisting = true
        for elem in elements { self.reappend(elem) }
    }
}
