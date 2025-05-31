import Foundation

let argv = CommandLine.arguments
guard argv.count == 1 else {
    print("extra arguments detected-\u{10}doing experiments only")

    exit(0)
}

Task {
    hotkeys(await WindConductor())
}
RunLoop.current.run()
