class Box<T> {
    var item: T

    init(_ item: T) {
        self.item = item
    }

    func leak() -> UnsafeMutableRawPointer {
        return Unmanaged.passUnretained(self).toOpaque()
    }

    static func unleak(ptr: UnsafeMutableRawPointer) -> Box<T> {
        return Unmanaged<Box<T>>.fromOpaque(ptr).takeUnretainedValue()
    }
}
