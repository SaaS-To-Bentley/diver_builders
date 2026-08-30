import Foundation
import PackagePlugin

/// `swift package diver-build` — runs the DiverScanner against every source
/// module in the package and writes `diver/app_urls.json` at the package root.
@main
struct DiverBuildPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "DiverScanner")
        let outputPath = context.package.directory.appending(subpath: "diver/app_urls.json")

        var args = ["--output", outputPath.string]
        for target in context.package.targets {
            guard let module = target as? SourceModuleTarget else { continue }
            args.append(module.directory.string)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.path.string)
        process.arguments = args
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            Diagnostics.error("DiverScanner exited with status \(process.terminationStatus)")
        } else {
            print("Diver: wrote \(outputPath.string)")
        }
    }
}
