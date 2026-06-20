import Foundation
import TelluricCore
import TelluricDiagnostics
import XCTest

final class DiagnosticsTests: XCTestCase {
    func testDiagnosticReportRoundTripsThroughJSON() throws {
        let report = DiagnosticReport(messages: [
            DiagnosticMessage(
                severity: .warning,
                code: NamespaceID("asset.missing.preview"),
                message: "Preview asset was not found.",
                source: "asset-cooker",
                metadata: [DiagnosticMetadata(key: "asset", value: "oak_tree")]
            ),
        ])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(report)
        let decoded = try JSONDecoder().decode(DiagnosticReport.self, from: data)

        XCTAssertEqual(decoded, report)
        XCTAssertEqual(decoded.summary, DiagnosticSummary(infos: 0, warnings: 1, errors: 0))
    }

    func testDiagnosticCollectorRecordsSeverities() {
        var collector = DiagnosticCollector()
        collector.record(severity: .info, code: NamespaceID("seed.audit.started"), message: "Audit started.")
        collector.record(severity: .warning, code: NamespaceID("seed.audit.warning"), message: "Non-fatal issue.")
        collector.record(severity: .error, code: NamespaceID("seed.audit.failed"), message: "Audit failed.")

        let report = collector.report()

        XCTAssertEqual(report.count(.info), 1)
        XCTAssertEqual(report.count(.warning), 1)
        XCTAssertEqual(report.count(.error), 1)
        XCTAssertTrue(report.hasErrors)
    }
}
