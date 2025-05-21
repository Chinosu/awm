postfix operator &
postfix func & <T>(left: inout T) -> UnsafeMutablePointer<T> {
    withUnsafeMutablePointer(to: &left, \.self)
}

postfix operator *
postfix func * <T>(left: UnsafeMutablePointer<T>) -> T {
    left.pointee
}

infix operator =*
func =* <T>(left: UnsafeMutablePointer<T>, right: T) {
    left.pointee = right
}

extension UnsafeMutablePointer {
    var a: Int {
        return 2
    }
}

postfix operator &~
postfix func &~ <T>(left: inout T) -> UnsafeMutableRawPointer {
    UnsafeMutableRawPointer(left&)
}

infix operator => : CastingPrecedence
func => <T>(left: UnsafeMutableRawPointer, right: T.Type) -> UnsafeMutablePointer<T> {
    left.assumingMemoryBound(to: right)
}

func operators() {
    var x = 42
    let ptr = x&
    print(ptr*)
    ptr =* 2
    // print(ptr.*)  // 42
}
