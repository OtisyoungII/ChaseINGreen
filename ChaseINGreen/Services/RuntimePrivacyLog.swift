import Foundation

// Module-local print sink covers existing call sites without changing financial/UI behavior.
// Explicit Swift.print bypasses are prohibited by the regression test/source audit.
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let text = items.map { String(describing: $0) }.joined(separator: separator)
    Swift.print(LogPrivacyPolicy.sanitize(text), terminator: "\n")
}
