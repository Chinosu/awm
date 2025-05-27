extension LinkedSet: ExpressibleByArrayLiteral {
    typealias ArrayLiteralElement = Element

    init(arrayLiteral elements: Element...) {
        for elem in elements { self.reappend(elem) }
    }
}
