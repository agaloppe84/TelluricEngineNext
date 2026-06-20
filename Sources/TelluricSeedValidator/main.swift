import Darwin
import Foundation
import TelluricSeedValidatorCore

@main
enum TelluricSeedValidatorMain {
    static func main() {
        do {
            let arguments = try SeedValidatorArgumentParser.parse(Array(CommandLine.arguments.dropFirst()))

            if arguments.help {
                print(SeedValidatorHelp.text)
                Darwin.exit(0)
            }

            let result = try SeedValidator().run(arguments: arguments)
            print(result.summary)
            Darwin.exit(result.exitCode)
        } catch let error as SeedValidatorArgumentError {
            writeError("\(error)\n\n\(SeedValidatorHelp.text)")
            Darwin.exit(2)
        } catch {
            writeError("telluric-seed-validator failed: \(String(describing: error))")
            Darwin.exit(1)
        }
    }

    private static func writeError(_ message: String) {
        let data = Data((message + "\n").utf8)
        FileHandle.standardError.write(data)
    }
}
