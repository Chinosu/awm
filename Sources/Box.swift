class Box<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }

    func raw() -> UnsafeMutableRawPointer {
        return Unmanaged.passUnretained(self).toOpaque()
    }

    static func from(raw ptr: UnsafeMutableRawPointer) -> T {
        return Unmanaged<Box<T>>.fromOpaque(ptr).takeUnretainedValue().value
    }
}
