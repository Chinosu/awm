import Foundation

let argv = CommandLine.arguments
if argv.count > 1 {
    print("extra arguments detected-\ndoing experiments only")
    await experiments()
    exit(0)
}
var wm = WindowManager()
hotkeys(&wm)
// RunLoop.main.run()
