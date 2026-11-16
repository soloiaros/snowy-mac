import Foundation

public struct SnowParticle: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var radius: Float
    public var opacity: Float
    var phase: Float
    var remainingLife: Float
    public var mass: Float = 1
    /// True while the flake clings to a vertical wall this frame.
    var isSliding = false
    /// Free-fall velocity to resume once the flake leaves the wall.
    var freeVelocity: SIMD2<Float>?
}

/// GPU layouts match Metal: 16 bytes per snow vertex and falling-flake instance.
public struct SnowVertex: Sendable {
    public var position: SIMD2<Float>
    public var material: SIMD2<Float>
}

public struct ParticleInstance: Sendable {
    public var position: SIMD2<Float>
    public var radius: Float
    public var opacity: Float
    public init(_ particle: SnowParticle) {
        position = particle.position
        radius = particle.radius
        opacity = particle.opacity * min(1, particle.remainingLife * 2)
    }
}
