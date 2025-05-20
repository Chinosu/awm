import Foundation

let argv = CommandLine.arguments
if argv.count > 1 {
    print("extra arguments detected-\u{10}doing experiments only")
    // Task {
    //     _ = await Observers.init()
    //     print("init finished. i'm waiting!")
    // }
    // RunLoop.current.run()
    // print(++"asd")

    dev()
    exit(0)
}

let wc = WindowConductor()
hotkeys(wc)
// RunLoop.main.run()
