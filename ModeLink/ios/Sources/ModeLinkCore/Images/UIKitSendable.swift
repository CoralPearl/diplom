import UIKit

// UIKit types are not annotated as Sendable in some SDK/toolchain combinations.
// For our use-case (images are treated as immutable after decoding), this is safe enough.
extension UIImage: @unchecked Sendable {}
