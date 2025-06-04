import SwiftUI

struct SizePreferenceKey: PreferenceKey {

		static var defaultValue: CGSize = .zero

		static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
				value = nextValue()
		}
}

public struct MeasureSizeModifier: ViewModifier {

		public func body(content: Content) -> some View {
				content.background(GeometryReader { geometry in
						Color.clear.preference(key: SizePreferenceKey.self,
																	 value: geometry.size)
				})
		}
}

public extension View {

		/// Measures the size of an element and calls the supplied closure.
		func CC_measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
				self.modifier(MeasureSizeModifier())
						.onPreferenceChange(SizePreferenceKey.self, perform: action)
		}
}

public struct FlippedUpsideDown: ViewModifier {
	public func body(content: Content) -> some View {
		content
			.rotationEffect(.radians(.pi))
			.scaleEffect(x: -1, y: 1, anchor: .center)
	}
}

extension View {
	public func flippedUpsideDown() -> some View {
		modifier(FlippedUpsideDown())
	}
}
