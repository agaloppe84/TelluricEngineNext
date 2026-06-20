import Foundation
import TelluricMath
import TelluricStreaming
import TelluricWorld
import XCTest

final class StreamingPlannerTests: XCTestCase {
    func testObserverAtOriginRadiusZeroRequestsExactlyOneChunk() {
        let plan = makePlan(radius: 0)

        XCTAssertTrue(plan.success)
        XCTAssertEqual(plan.chunksToRequest.map(\.chunkCoord), [.zero])
        XCTAssertEqual(plan.chunksToKeep, [])
        XCTAssertEqual(plan.chunksToEvict, [])
    }

    func testObserverAtOriginRadiusOneRequestsExactlyNineChunks() {
        let plan = makePlan(radius: 1)

        XCTAssertTrue(plan.success)
        XCTAssertEqual(plan.chunksToRequest.count, 9)
    }

    func testObserverAtOriginRadiusTwoRequestsExactlyTwentyFiveChunks() {
        let plan = makePlan(radius: 2)

        XCTAssertTrue(plan.success)
        XCTAssertEqual(plan.chunksToRequest.count, 25)
    }

    func testChunkOrderingIsDeterministic() {
        let plan = makePlan(radius: 1)
        let expected = [
            ChunkCoord(x: 0, y: 0, z: 0),
            ChunkCoord(x: -1, y: 0, z: 0),
            ChunkCoord(x: 0, y: 0, z: -1),
            ChunkCoord(x: 0, y: 0, z: 1),
            ChunkCoord(x: 1, y: 0, z: 0),
            ChunkCoord(x: -1, y: 0, z: -1),
            ChunkCoord(x: -1, y: 0, z: 1),
            ChunkCoord(x: 1, y: 0, z: -1),
            ChunkCoord(x: 1, y: 0, z: 1),
        ]

        XCTAssertEqual(plan.chunksToRequest.map(\.chunkCoord), expected)
    }

    func testNearestChunksHaveHigherPriorityThanFarChunks() {
        let plan = makePlan(radius: 2)

        XCTAssertLessThan(plan.chunksToRequest[0].priority, plan.chunksToRequest[1].priority)
        XCTAssertLessThan(plan.chunksToRequest[1].priority, plan.chunksToRequest.last!.priority)
        XCTAssertEqual(plan.chunksToRequest[0].priority.manhattanDistance, 0)
        XCTAssertEqual(plan.chunksToRequest.last!.priority.manhattanDistance, 4)
    }

    func testTieBreakOrderingIsStable() {
        let plan = makePlan(radius: 1)
        let distanceOne = plan.chunksToRequest.filter { $0.priority.manhattanDistance == 1 }

        XCTAssertEqual(distanceOne.map(\.chunkCoord), [
            ChunkCoord(x: -1, y: 0, z: 0),
            ChunkCoord(x: 0, y: 0, z: -1),
            ChunkCoord(x: 0, y: 0, z: 1),
            ChunkCoord(x: 1, y: 0, z: 0),
        ])
    }

    func testExistingResidentDesiredChunkIsKeptNotRequested() {
        let plan = makePlan(
            radius: 0,
            residency: ChunkResidencySnapshot(records: [
                ChunkResidencyRecord(chunkCoord: .zero, state: .resident),
            ])
        )

        XCTAssertEqual(plan.chunksToRequest, [])
        XCTAssertEqual(plan.chunksToKeep.map(\.chunkCoord), [.zero])
        XCTAssertEqual(plan.chunksToEvict, [])
    }

    func testExistingResidentUndesiredChunkIsEvicted() {
        let staleChunk = ChunkCoord(x: 4, y: 0, z: 0)
        let plan = makePlan(
            radius: 0,
            residency: ChunkResidencySnapshot(records: [
                ChunkResidencyRecord(chunkCoord: staleChunk, state: .resident),
            ])
        )

        XCTAssertEqual(plan.chunksToRequest.map(\.chunkCoord), [.zero])
        XCTAssertEqual(plan.chunksToKeep, [])
        XCTAssertEqual(plan.chunksToEvict, [
            ChunkResidencyRecord(chunkCoord: staleChunk, state: .resident),
        ])
    }

    func testSameInputProducesIdenticalPlan() {
        let residency = ChunkResidencySnapshot(records: [
            ChunkResidencyRecord(chunkCoord: .zero, state: .resident),
            ChunkResidencyRecord(chunkCoord: ChunkCoord(x: 2, y: 0, z: 0), state: .ready),
        ])
        let first = makePlan(radius: 1, residency: residency)
        let second = makePlan(radius: 1, residency: residency)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.stableHash, second.stableHash)
    }

    func testMovingObserverChangesRequestKeepAndEvictSets() {
        let observer = StreamingObserver(
            id: StreamingObserverID("observer.main"),
            worldPosition: Int3(x: 16, y: 0, z: 0)
        )
        let plan = makePlan(
            radius: 0,
            observers: [observer],
            residency: ChunkResidencySnapshot(records: [
                ChunkResidencyRecord(chunkCoord: .zero, state: .resident),
            ])
        )

        XCTAssertEqual(plan.chunksToRequest.map(\.chunkCoord), [
            ChunkCoord(x: 1, y: 0, z: 0),
        ])
        XCTAssertEqual(plan.chunksToKeep, [])
        XCTAssertEqual(plan.chunksToEvict.map(\.chunkCoord), [.zero])
    }

    func testNegativeWorldPositionUsesFloorDivisionForChunkConversion() {
        let chunkCoord = ChunkStreamingPlanner.chunkCoord(
            forWorldPosition: Int3(x: -1, y: 0, z: -16),
            chunkSize: 16
        )

        XCTAssertEqual(chunkCoord, ChunkCoord(x: -1, y: 0, z: -1))
    }

    func testNegativeRadiusFailsValidation() {
        let plan = makePlan(radius: -1)

        XCTAssertFalse(plan.success)
        XCTAssertTrue(plan.diagnostics.hasErrors)
        XCTAssertTrue(plan.diagnostics.messages.contains { $0.code.rawValue == "streaming.config.invalid_radius" })
    }

    func testInvalidChunkSizeFailsValidation() {
        let plan = ChunkStreamingPlanner().plan(
            config: ChunkStreamingConfig(chunkSize: 0, radius: 1),
            observers: [defaultObserver()],
            residency: .empty
        )

        XCTAssertFalse(plan.success)
        XCTAssertTrue(plan.diagnostics.hasErrors)
        XCTAssertTrue(plan.diagnostics.messages.contains { $0.code.rawValue == "streaming.config.invalid_chunk_size" })
    }

    func testPlanEncodesAndDecodes() throws {
        let plan = makePlan(radius: 1)

        XCTAssertEqual(try roundTrip(plan), plan)
    }

    private func makePlan(
        radius: Int,
        observers: [StreamingObserver]? = nil,
        residency: ChunkResidencySnapshot = .empty
    ) -> ChunkStreamingPlan {
        ChunkStreamingPlanner().plan(
            config: ChunkStreamingConfig(chunkSize: 16, radius: radius),
            observers: observers ?? [defaultObserver()],
            residency: residency
        )
    }

    private func defaultObserver() -> StreamingObserver {
        StreamingObserver(
            id: StreamingObserverID("observer.main"),
            worldPosition: .zero
        )
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
