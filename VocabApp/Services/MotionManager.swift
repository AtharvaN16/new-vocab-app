import CoreMotion
import Observation

@Observable
final class MotionManager {
    // Normalized tilt in [-1, 1], already inverted
    var tiltX: Double = 0  // forward/back: phone tilts forward → word tips backward
    var tiltY: Double = 0  // left/right:   phone tilts left   → word tips right

    private let cm = CMMotionManager()
    private let smoothing = 0.12

    // Gravity component at which card reaches full tilt (~8.6° of phone tilt)
    private let sensitivity = 0.15

    func start() {
        guard cm.isDeviceMotionAvailable else { return }
        cm.deviceMotionUpdateInterval = 1.0 / 60.0
        // Use gravity vector instead of Euler angles — avoids gimbal lock when
        // phone is held upright (portrait), where pitch decomposition breaks.
        cm.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            let g = motion.gravity
            // gravity.x: left/right lean. Inverted: left tilt → positive tiltY → card tips right
            // gravity.z: forward/back lean. Inverted: forward tilt (gz negative) → positive tiltX → card tips back
            let targetX = max(-1, min(1, -g.z / self.sensitivity))
            let targetY = max(-1, min(1, -g.x / self.sensitivity))

            self.tiltX += self.smoothing * (targetX - self.tiltX)
            self.tiltY += self.smoothing * (targetY - self.tiltY)
        }
    }

    func stop() {
        cm.stopDeviceMotionUpdates()
        tiltX = 0
        tiltY = 0
    }
}
