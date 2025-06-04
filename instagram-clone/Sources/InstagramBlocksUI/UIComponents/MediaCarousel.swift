import AppUI
import BlurHashClient
import ComposableArchitecture
import Kingfisher
import Shared
import SwiftUI
import VideoPlayer

@Reducer
public struct MediaCarouselReducer {
	public init() {}
	@ObservableState
	public struct State: Equatable {
		var media: IdentifiedArrayOf<MediaItem>
		var blurHashImages: [String: UIImage] = [:]
		@Shared var currentMediaIndex: Int
		var playingVideoMediaId: String? // media id
		var currentMediaPosition: String? // media id
		var playVideo = false
		@Shared var videoMuted: Bool
		public init(
			media: [MediaItem],
			currentMediaIndex: Shared<Int>,
			videoMuted: Shared<Bool>
		) {
			self._currentMediaIndex = currentMediaIndex
			self._videoMuted = videoMuted
			self.media = IdentifiedArray(uniqueElements: media)
			self.currentMediaPosition = media.first?.id
		}
	}

	public enum Action: BindableAction {
		case binding(BindingAction<State>)
		case task
		case mediaHashImagesResponse([String: UIImage])
		case startPlayVideo(mediaId: String)
		case stopPlayVideo(mediaId: String)
		case mediaPositionUpdated(mediaId: String?)
	}

	@Dependency(\.blurHashClient.decode) var blurHash

	public var body: some ReducerOf<Self> {
		BindingReducer()
		Reduce {
			state,
				action in
			switch action {
			case .binding:
				return .none
			case .task:
				return .run { [media = state.media] send in
					let blurHashImages = await withTaskGroup(of: (String, UIImage?).self) { group in
						for item in media {
							group.addTask {
								if let blurHashString = item.blurHash,
								   !blurHashString.isEmpty
								{
									return (item.id, await blurHash(blurHashString))
								}
								return (item.id, nil)
							}
						}

						var results: [String: UIImage] = [:]
						for await (id, blurHashImage) in group where blurHashImage != nil {
							results[id] = blurHashImage
						}
						return results
					}
					await send(.mediaHashImagesResponse(blurHashImages))
				}
			case let .mediaHashImagesResponse(blurHashImages):
				state.blurHashImages = blurHashImages
				return .none
			case let .startPlayVideo(mediaId):
				state.playingVideoMediaId = mediaId
				return .none
			case let .stopPlayVideo(mediaId):
//				guard state.playingVideoMediaId == mediaId else {
//					return .none
//				}
				state.playingVideoMediaId = nil
				return .none
			case let .mediaPositionUpdated(mediaId):
				guard let mediaId else {
					return .none
				}
				guard let mediaIndex = state.media.index(id: mediaId) else {
					return .none
				}
				state.currentMediaIndex = mediaIndex
				guard state.currentMediaPosition != mediaId else {
					return .none
				}
				state.currentMediaPosition = mediaId
				if let playingVideoMediaId = state.playingVideoMediaId,
				   playingVideoMediaId != state.currentMediaPosition
				{
					state.playingVideoMediaId = nil
				} else {
					if let currentPositionMedia = state.media[id: mediaId],
					   currentPositionMedia.isVideo
					{
						state.playingVideoMediaId = mediaId
					}
				}
				return .none
			}
		}
	}
}

public struct MediaCarouselView: View {
	@Bindable var store: StoreOf<MediaCarouselReducer>
	@Environment(\.colorScheme) var colorScheme
	@State private var playingVideoMediaId: String?
	public init(store: StoreOf<MediaCarouselReducer>) {
		self.store = store
	}

	public var body: some View {
		ScrollView(.horizontal) {
			LazyHStack {
				ForEach(store.media) { media in
					mediaCarouselPage(media: media)
				}
			}
		}
		.scrollPosition(id: $store.currentMediaPosition.sending(\.mediaPositionUpdated))
		.scrollIndicators(.hidden)
		.scrollTargetBehavior(.viewAligned)
		.scrollTargetLayout()
		.onDisappear {
			playingVideoMediaId = nil
		}
		.task {
			await store.send(.task).finish()
		}
	}

	@ViewBuilder
	private func mediaCarouselPage(media: MediaItem) -> some View {
		GeometryReader { geometry in
			Group {
				if !media.isVideo || playingVideoMediaId == nil {
					if let previewData = media.previewData {
						Image(uiImage: UIImage(data: previewData)!)
							.resizable()
							.scaledToFill()
							.frame(width: geometry.size.width, height: geometry.size.height)
							.clipped()
					} else {
						KFImage.url(URL(string: media.previewUrl ?? ""))
							.placeholder {
								if let blurHashImage = store.blurHashImages[media.id] {
									Image(uiImage: blurHashImage)
										.resizable()
								} else {
									Assets.Colors.customAdaptiveColor(
										colorScheme,
										light: Assets.Colors.gray,
										dark: Assets.Colors.darkGray
									)
								}
							}
							.resizable()
							.fade(duration: 0.2)
							.scaledToFill()
							.frame(width: geometry.size.width, height: geometry.size.height)
							.clipped()
					}
				} else {
					VideoPlayer(
						url: URL(string: media.url) ?? URL(string: "nil://placeholder")!,
						play: Binding(
							get: { playingVideoMediaId == media.id },
							set: { playing in
								if playing {
									playingVideoMediaId = media.id
								} else {
									playingVideoMediaId = nil
								}
							}
						)
					)
					.mute(store.videoMuted || playingVideoMediaId == nil)
					.autoReplay(true)
					.frame(width: geometry.size.width, height: geometry.size.height)
					.onDisappear {
						playingVideoMediaId = nil
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			
		}
		.scaledToFill()
		.id(media.id)
		.containerRelativeFrame(.horizontal)
		.onAppear {
			if media.isVideo {
				playingVideoMediaId = media.id
			}
		}
		.onDisappear {
			playingVideoMediaId = nil
		}
		.scrollTargetLayout()
	}
}

#Preview {
	MediaCarouselView(
		store: Store(
			initialState: MediaCarouselReducer.State(
				media: [
					.image(ImageMedia(id: "123445", url: "https://uuhkqhxfbjovbighyxab.supabase.co/storage/v1/object/public/posts/079b8318-51bc-4b50-80ac-fbf42361124d/image_0", blurHash: "LVC?N0af9+bJ0ga{-ijX=@e-N2az")),
					.video(
						VideoMedia(
							id: "d7784ce7-49ca-461a-ab52-14017f9be458",
							url: "https://uuhkqhxfbjovbighyxab.supabase.co/storage/v1/object/public/posts/00c8e0ea-d59e-45ee-b0d6-5034ff2d61e2/video_0",
							blurHash: "LQKT[CR*?v-p~Vx^V@jb?aInRPWX",
							firstFrameUrl: "https://uuhkqhxfbjovbighyxab.supabase.co/storage/v1/object/public/posts/00c8e0ea-d59e-45ee-b0d6-5034ff2d61e2/video_first_frame_0)"
						)
					)
				],
				currentMediaIndex: Shared(0),
				videoMuted: Shared(true)
			),
			reducer: { MediaCarouselReducer()
			}
		)
	)
}
