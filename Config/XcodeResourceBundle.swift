import Foundation

// SwiftPM synthesizes this accessor for processed resources. The checked-in
// Xcode application target embeds those same resources directly in its main
// bundle, so this Xcode-only source keeps the shared studio code unchanged.
extension Bundle {
    static let module = Bundle.main
}
