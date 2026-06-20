import Darwin
import Foundation
import TelluricHeadlessLoopCore

@main
enum TelluricHeadlessLoopMain {
    static func main() {
        do {
            let arguments = try HeadlessLoopArgumentParser.parse(Array(CommandLine.arguments.dropFirst()))

            if arguments.help {
                print(HeadlessLoopHelp.text)
                Darwin.exit(0)
            }

            let result = try HeadlessLoopRunner().run(arguments: arguments)
            print(result.summary)
            Darwin.exit(result.exitCode)
        } catch let error as HeadlessLoopArgumentError {
            writeError("\(error)\n\n\(HeadlessLoopHelp.text)")
            Darwin.exit(2)
        } catch {
            writeError("telluric-headless-loop failed: \(String(describing: error))")
            Darwin.exit(1)
        }
    }

    private static func writeError(_ message: String) {
        let data = Data((message + "\n").utf8)
        FileHandle.standardError.write(data)
    }
}
