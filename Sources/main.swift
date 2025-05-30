import Foundation

let argv = CommandLine.arguments
guard argv.count == 1 else {
    print("extra arguments detected-\u{10}doing experiments only")

    Task {
        dev_hotkeys(await WC())
    }
    RunLoop.current.run()

    exit(0)
}

Task {
    let wc = await WindConductor()
    hotkeys(wc)
}
RunLoop.current.run()
