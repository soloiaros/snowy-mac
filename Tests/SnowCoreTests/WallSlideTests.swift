import Foundation
import XCTest
@testable import SnowCore

/// Falling snow that meets a vertical face (a window side or a screen edge) clings to it and
/// slides down, then falls freely again below the wall, instead of vanishing on contact.
final class WallSlideTests: XCTestCase {
    private let wall = SolidBody(id: 7, bounds: CGRect(x: 500, y: 100, width: 300, height: 600))

    private func world(flakes: Int = 0) -> SnowSimulation {
        let simulation = SnowSimulation(size: SIMD2(1000, 800), budget: SimulationBudget(flakes: flakes), seed: 3)
        simulation.updateScene(surfaces: [], bodies: [wall])
        return simulation
    }

    private func flake(at position: SIMD2<Float>, velocity: SIMD2<Float>) -> SnowParticle {
        SnowParticle(position: position, velocity: velocity, radius: 1.5, opacity: 1,
                     phase: 0, remainingLife: 100, mass: 1)
    }

    func testFlakeMeetingAWindowSideClingsAndSlidesInsteadOfVanishing() {
        let simulation = world()
        var particle = flake(at: SIMD2(480, 300), velocity: SIMD2(60, 30))

        let recycled = simulation.advanceParticle(&particle, dt: 0.5, recycleOnContact: true)

        XCTAssertFalse(recycled)
        XCTAssertTrue(particle.isSliding)
        XCTAssertEqual(particle.position.x, 500 - particle.radius, accuracy: 0.5)
        XCTAssertEqual(particle.velocity.x, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(particle.velocity.y, 0)
        XCTAssertLessThan(particle.velocity.y, 30, "Sliding is slower than free fall")
    }

    func testFlakeHittingATopStillLandsOrRecycles() {
        let simulation = world()
        var particle = flake(at: SIMD2(650, 80), velocity: SIMD2(0, 60))
        XCTAssertTrue(simulation.advanceParticle(&particle, dt: 0.5, recycleOnContact: true))
        XCTAssertFalse(particle.isSliding)
    }

    func testFlakeSlidesDownTheWallThenRejoinsTheWindBelowIt() {
        let simulation = world(flakes: 1)
        simulation.snowfall = .flurry
        simulation.wind = WindSettings(vector: SIMD2(1, 0))
        simulation.step(dt: 1 / 30, cursor: nil)
        simulation.flakes[0] = flake(at: SIMD2(497, 640), velocity: SIMD2(0, 40))

        var path: [SIMD2<Float>] = []
        var slidingFrames = 0
        for _ in 0..<300 {
            simulation.step(dt: 1 / 30, cursor: nil)
            path.append(simulation.flakes[0].position)
            if simulation.flakes[0].isSliding { slidingFrames += 1 }
            if simulation.flakes[0].position.y > 740 { break } // Below the wall; stop before it lands.
        }
        // Clinging is steady rather than flickering on and off every other frame.
        XCTAssertGreaterThan(slidingFrames, path.filter { $0.y < 695 }.count * 9 / 10)
        // Not recycled to the top while beside the wall: y only increases.
        XCTAssertTrue(zip(path, path.dropFirst()).allSatisfy { $1.y >= $0.y - 0.01 }, "Flake vanished or jumped")
        // Pressed against the wall while beside it.
        for point in path where point.y < 695 {
            XCTAssertEqual(point.x, 500 - 1.5, accuracy: 2.5)
        }
        // Below the wall the crosswind carries it under the window again.
        XCTAssertGreaterThan(path.last!.y, 700)
        XCTAssertGreaterThan(path.last!.x, 520)
    }
}
