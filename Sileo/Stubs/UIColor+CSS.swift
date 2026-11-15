// Sileo demo (userland) stub — replaces the UIColor+HTMLColors CSS parser
// (was Sileo/Contrib/UIColor+HTMLColors.{h,m}, deleted with the backend).
//
// The UI calls UIColor(css:) in 8 depiction/featured views and in
// PackageViewController for tint colors. The original +colorWithCSS: handled
// full CSS (names, hsl, rgb); the demo only needs the hex forms depiction
// JSON actually uses. Anything unparseable returns nil, exactly like the
// original, so callers fall back to their default color.

import UIKit

extension UIColor {

    public convenience init?(css: String) {
        let text = css.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            guard let color = UIColor(hexString: String(text.dropFirst())) else {
                return nil
            }
            self.init(cgColor: color.cgColor)
            return
        }
        if text.lowercased().hasPrefix("rgb") {
            guard let color = UIColor(rgbString: text) else {
                return nil
            }
            self.init(cgColor: color.cgColor)
            return
        }
        return nil
    }

    private convenience init?(hexString hex: String) {
        var value: UInt64 = 0
        let scanner = Scanner(string: hex)
        guard scanner.scanHexInt64(&value), scanner.isAtEnd else {
            return nil
        }
        switch hex.count {
        case 3: // #RGB
            let r = CGFloat((value >> 8) & 0xF) / 15.0
            let g = CGFloat((value >> 4) & 0xF) / 15.0
            let b = CGFloat(value & 0xF) / 15.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        case 6: // #RRGGBB
            let r = CGFloat((value >> 16) & 0xFF) / 255.0
            let g = CGFloat((value >> 8) & 0xFF) / 255.0
            let b = CGFloat(value & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        case 8: // #AARRGGBB
            let a = CGFloat((value >> 24) & 0xFF) / 255.0
            let r = CGFloat((value >> 16) & 0xFF) / 255.0
            let g = CGFloat((value >> 8) & 0xFF) / 255.0
            let b = CGFloat(value & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }

    private convenience init?(rgbString text: String) {
        let inner = text
            .replacingOccurrences(of: "rgba", with: "")
            .replacingOccurrences(of: "rgb", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
        let parts = inner.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count == 3 || parts.count == 4,
              let r = Double(parts[0]), let g = Double(parts[1]),
              let b = Double(parts[2]) else {
            return nil
        }
        let a = parts.count == 4 ? (Double(parts[3]) ?? 1.0) : 1.0
        self.init(red: CGFloat(r / 255.0), green: CGFloat(g / 255.0),
                  blue: CGFloat(b / 255.0), alpha: CGFloat(a))
    }
}
