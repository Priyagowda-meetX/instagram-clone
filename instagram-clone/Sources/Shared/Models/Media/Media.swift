import Foundation

public protocol Media: Equatable, Codable, Hashable {
	var id: String { get }
	var url: String { get }
	var blurHash: String? { get }
	var type: String { get }
	var previewData: Data? { get }
	static var identifier: String { get }
}

public enum MediaItem: Equatable, Codable, Identifiable, Hashable {
	case memoryImage(MemoryImageMedia)
	case memoryVideo(MemoryVideoMedia)
	case image(ImageMedia)
	case video(VideoMedia)

	public var id: String {
		switch self {
		case .memoryImage(let memoryImageMedia): return memoryImageMedia.id
		case .memoryVideo(let memoryVideoMedia): return memoryVideoMedia.id
		case let .image(imageMedia): return imageMedia.id
		case let .video(videoMedia): return videoMedia.id
		}
	}

	public var url: String {
		switch self {
		case .memoryImage(let memoryImageMedia): return memoryImageMedia.url
		case .memoryVideo(let memoryVideoMedia): return memoryVideoMedia.url
		case let .image(imageMedia): return imageMedia.url
		case let .video(videoMedia): return videoMedia.url
		}
	}

	public var blurHash: String? {
		switch self {
		case .memoryImage(let memoryImageMedia): return memoryImageMedia.blurHash
		case .memoryVideo(let memoryVideoMedia): return memoryVideoMedia.blurHash
		case let .image(imageMedia): return imageMedia.blurHash
		case let .video(videoMedia): return videoMedia.blurHash
		}
	}

	private enum CodingKeys: String, CodingKey {
		case type
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
		case ImageMedia.identifier:
			let imageMedia = try ImageMedia(from: decoder)
			self = .image(imageMedia)
		case VideoMedia.identifier:
			let videoMedia = try VideoMedia(from: decoder)
			self = .video(videoMedia)
		default:
			throw DecodingError.dataCorruptedError(
				forKey: .type,
				in: container,
				debugDescription: "Unknown media type: \(type)"
			)
		}
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case let .image(imageMedia):
			try container.encode(imageMedia)
		case let .video(videoMedia):
			try container.encode(videoMedia)
		default: fatalError("InMemory type should not call encode")
		}
	}

	public var firstFrameUrl: String? {
		guard case let .video(videoMedia) = self else {
			return nil
		}
		return videoMedia.firstFrameUrl
	}
	
	public var isVideo: Bool {
		switch self {
		case .memoryImage: return false
		case .memoryVideo: return true
		case .image: return false
		case .video: return true
		}
	}
	
	public var previewUrl: String? {
		switch self {
		case .image(let imageMedia): return imageMedia.url
		case .video(let videoMedia): return videoMedia.firstFrameUrl
		case let .memoryImage(imageMedia): return imageMedia.url
		case let .memoryVideo(videoMeida): return videoMeida.url
		}
	}
	
	public var previewData: Data? {
		switch self {
		case .image: return nil
		case .video: return nil
		case let .memoryImage(imageMedia): return imageMedia.previewData
		case let .memoryVideo(videoMedia): return videoMedia.previewData
		}
	}
}

public struct MemoryImageMedia: Media {
	
	
	public static var identifier: String {
		"__memory_image_media__"
	}

	public var id: String
	public var url: String
	public var blurHash: String?
	public var previewData: Data?
	public init(id: String, url: String, previewData: Data?, blurHash: String? = nil) {
		self.id = id
		self.url = url
		self.previewData = previewData
		self.blurHash = blurHash
	}

	public var type: String {
		MemoryImageMedia.identifier
	}
}

public struct MemoryVideoMedia: Media {
	public static var identifier: String {
		"__memory_video_media__"
	}

	public var id: String
	public var url: String
	public var previewData: Data?
	public var blurHash: String?
	public init(id: String, url: String, previewData: Data?, blurHash: String? = nil) {
		self.id = id
		self.url = url
		self.previewData = previewData
		self.blurHash = blurHash
	}

	public var type: String {
		MemoryVideoMedia.identifier
	}
}
