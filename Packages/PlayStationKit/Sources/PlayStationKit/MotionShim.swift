// Apple TV has no device motion sensors and no CoreMotion. StreamInput (from Pylux) uses the phone's
// sensors as a fallback when the controller has none; on tvOS this stand-in reports "unavailable", so
// motion comes only from the controller (a DualSense's gyro), which is the right behavior on a TV.
#if os(tvOS)
import Foundation

struct MotionVector {
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
}

final class CMDeviceMotion {
    let rotationRate = MotionVector()
    let gravity = MotionVector()
    let userAcceleration = MotionVector()
}

final class CMMotionManager {
    var isDeviceMotionActive: Bool { false }
    var isDeviceMotionAvailable: Bool { false }
    var deviceMotionUpdateInterval: TimeInterval = 0
    var deviceMotion: CMDeviceMotion? { nil }
    func startDeviceMotionUpdates(to queue: OperationQueue, withHandler handler: @escaping (CMDeviceMotion?, Error?) -> Void) {}
    func stopDeviceMotionUpdates() {}
}
#endif
