import Darwin
import Foundation
import TelluricAssetCookerCore

@main
enum TelluricAssetCookerMain {
    static func main() {
        do {
            let arguments = try AssetCookerArgumentParser.parse(Array(CommandLine.arguments.dropFirst()))

            if arguments.help {
                print(AssetCookerHelp.text)
                Darwin.exit(0)
            }

            let result = try AssetCooker().run(arguments: arguments)
            print(result.summary)
            Darwin.exit(result.exitCode)
        } catch let error as AssetCookerArgumentError {
            writeError("\(error)\n\n\(AssetCookerHelp.text)")
            Darwin.exit(2)
        } catch {
            writeError("telluric-asset-cooker failed: \(String(describing: error))")
            Darwin.exit(1)
        }
    }

    private static func writeError(_ message: String) {
        let data = Data((message + "\n").utf8)
        FileHandle.standardError.write(data)
    }
}
