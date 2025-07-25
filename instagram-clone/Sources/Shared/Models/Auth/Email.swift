import Foundation

public struct Email: FormInput, Equatable, Sendable {
	
	public init(value: String, pure: Bool, error: Error?) {
		self.value = value
		self.pure = pure
		self.error = error
	}
	public init() {
		self.value = ""
		self.pure = true
		self.error = nil
	}
	
	public let value: String
	public let pure: Bool
	public let error: Error?
	
	public static func ==(lhs: Email, rhs: Email) -> Bool {
		lhs.value == rhs.value &&
		lhs.status == rhs.status
	}
}
