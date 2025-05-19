import Foundation

let argv = CommandLine.arguments
if argv.count > 1 {
    print("extra arguments detected-\u{10}doing experiments only")
    // Experiments.observers()
    // Experiments.topWindow()
    Task {
        _ = await Observers.init()
        print("init finished. i'm waiting!")
    }

    RunLoop.current.run()
    exit(0)
}

var wm = WindowManager()
hotkeys(&wm)
// RunLoop.main.run()
