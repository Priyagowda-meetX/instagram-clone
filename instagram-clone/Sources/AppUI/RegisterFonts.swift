import UIKit

@discardableResult
public func registerFonts() -> Bool {
	[
		UIFont.registerFont(bundle: .module, fontName: "Inter-Bold", fontExtension: "ttf"),
		UIFont.registerFont(bundle: .module, fontName: "Inter-ExtraBold", fontExtension: "ttf"),
		UIFont.registerFont(bundle: .module, fontName: "Inter-ExtraLight", fontExtension: "ttf"),
		UIFont.registerFont(bundle: .module, fontName: "Inter-Light", fontExtension: "ttf"),
		UIFont.registerFont(bundle: .module, fontName: "Inter-Medium", fontExtension: "ttf"),
		UIFont.registerFont(bundle: .module, fontName: "Inter-Regular", fontExtension: "ttf"),
		UIFont.registerFont(bundle: .module, fontName: "Inter-SemiBold", fontExtension: "ttf"),
		UIFont.registerFont(bundle: .module, fontName: "Montserrat-Medium", fontExtension: "ttf"),
	]
	.allSatisfy { $0 }
}

extension UIFont {
	static func registerFont(bundle: Bundle, fontName: String, fontExtension: String) -> Bool {
		guard let fontURL = bundle.url(forResource: fontName, withExtension: fontExtension) else {
			print("Couldn't find font \(fontName)")
			return false
		}
		guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL) else {
			print("Couldn't load data from the font \(fontName)")
			return false
		}
		guard let font = CGFont(fontDataProvider) else {
			print("Couldn't create font from data")
			return false
		}

		var error: Unmanaged<CFError>?
		let success = CTFontManagerRegisterGraphicsFont(font, &error)
		guard success else {
			print(
				"""
				Error registering font: \(fontName). Maybe it was already registered.\
				\(error.map { " \($0.takeUnretainedValue().localizedDescription)" } ?? "")
				"""
			)
			return true
		}

		return true
	}
}
