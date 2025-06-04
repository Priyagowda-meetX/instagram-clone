import AppUI
import ComposableArchitecture
import Foundation
import InstaBlocks
import Shared
import SwiftUI

/* final List<Media> media;
 final int? postIndex;
 final VoidCallback? likePost;
 final bool isLiked;
 final ValueSetter<int>? onPageChanged;
 final VideoPlayerBuilder? videoPlayerBuilder;
 final MediaCarouselSettings? mediaCarouselSettings;
 final bool withLikeOverlay;
 final bool withInViewNotifier;
 final bool autoHideCurrentIndex; */

@Reducer
public struct PostMediaReducer {
	public init() {}
	@ObservableState
	public struct State: Equatable {
		var media: [MediaItem]
		var postIndex: Int?
		var isLiked: Bool
		var withLikeOverlay: Bool
		var autoHideCurrentIndex: Bool
		var showCurrentIndex: Bool
		var isShowingCurrentIndex: Bool
		@Shared var currentMediaIndex: Int
		@Shared var videoMuted: Bool
		var carousel: MediaCarouselReducer.State
		public init(
			media: [MediaItem],
			postIndex: Int? = nil,
			isLiked: Bool,
			currentMediaIndex: Shared<Int>,
			showCurrentIndex: Bool = false,
			withLikeOverlay: Bool = false,
			autoHideCurrentIndex: Bool = true,
			videoMuted: Bool = true
		) {
			self.media = media
			self.postIndex = postIndex
			self.isLiked = isLiked
			self._currentMediaIndex = currentMediaIndex
			self.withLikeOverlay = withLikeOverlay
			self.autoHideCurrentIndex = autoHideCurrentIndex
			self.showCurrentIndex = showCurrentIndex
			self.isShowingCurrentIndex = showCurrentIndex
			self._videoMuted = Shared(videoMuted)
			self.carousel = MediaCarouselReducer.State(media: media, currentMediaIndex: self._currentMediaIndex, videoMuted: self._videoMuted)
		}

		var currentMedia: MediaItem {
			self.media[self.currentMediaIndex]
		}
	}

	public enum Action: BindableAction {
		case task
		case binding(BindingAction<State>)
		case carousel(MediaCarouselReducer.Action)
		case showCurrentMediaIndexTag
		case hideCurrentMediaIndexTag
		case currentMediaIndexDidUpdated
		case onTapSoundButton
		case delegate(Delegate)
		public enum Delegate {
			case didScrollToMediaIndex(Int)
		}
	}

	fileprivate enum Cancel: Hashable {
		case subscriptions
		case pageIndicatorTimer
	}

	public var body: some ReducerOf<Self> {
		BindingReducer()
		Scope(state: \.carousel, action: \.carousel) {
			MediaCarouselReducer()
		}
		Reduce {
			state,
				action in
			switch action {
			case .task:
				var effect = Effect<Action>.none
				// TODO: add other subscriptions here

				// hide media index effect
				let autoHideCurrentIndex = state.autoHideCurrentIndex
				let showCurrentIndex = state.showCurrentIndex
				let currentMediaIndexEffect: Effect<Action> =
					(autoHideCurrentIndex && showCurrentIndex) ? Effect.hidePageIndicatorTimer() : .none
				let currentMediaIndexPublisherEffect: Effect<Action> = .publisher {
					state.$currentMediaIndex.publisher
						.removeDuplicates()
						.receive(on: DispatchQueue.main)
						.map { _ in Action.currentMediaIndexDidUpdated }
				}
				effect = effect
					.concatenate(with: currentMediaIndexEffect)
					.concatenate(with: currentMediaIndexPublisherEffect)
				return effect
			case .binding:
				return .none
			case .carousel:
				return .none
			case .delegate:
				return .none
			case .showCurrentMediaIndexTag:
				if state.isShowingCurrentIndex {
					return Effect.concatenate(
						.cancel(id: Cancel.pageIndicatorTimer),
						.hidePageIndicatorTimer()
					)
				} else {
					state.isShowingCurrentIndex = true
				}
				if state.autoHideCurrentIndex {
					return .hidePageIndicatorTimer()
				} else {
					return .none
				}
			case .hideCurrentMediaIndexTag:
				state.isShowingCurrentIndex = false
				return .none
			case .onTapSoundButton:
				state.videoMuted.toggle()
				return .none
			case .currentMediaIndexDidUpdated:
				if state.autoHideCurrentIndex {
					return .send(.showCurrentMediaIndexTag)
				}
				return .none
			}
		}
	}
}

extension Effect where Action == PostMediaReducer.Action {
	static func hidePageIndicatorTimer() -> Effect<Action> {
		.run { send in
			@Dependency(\.continuousClock) var clock
			try await clock.sleep(for: .seconds(3))
			await send(.hideCurrentMediaIndexTag)
		}
		.cancellable(id: PostMediaReducer.Cancel.pageIndicatorTimer, cancelInFlight: true)
	}
}

public struct PostMediaView: View {
	@Bindable var store: StoreOf<PostMediaReducer>
	@Environment(\.textTheme) var textTheme
	@Environment(\.colorScheme) var colorScheme
	public init(store: StoreOf<PostMediaReducer>) {
		self.store = store
	}

	public var body: some View {
		MediaCarouselView(
			store: self.store.scope(
				state: \.carousel,
				action: \.carousel
			)
		)
		.overlay(alignment: .topTrailing) {
			if self.store.media.count > 1 && self.store.isShowingCurrentIndex {
				Text("\(self.store.currentMediaIndex + 1)/\(self.store.media.count)")
					.foregroundStyle(Assets.Colors.white)
					.padding(.horizontal, AppSpacing.md)
					.padding(.vertical, AppSpacing.xxs)
					.background(
						Assets.Colors.customAdaptiveColor(
							self.colorScheme,
							light: Assets.Colors.black.opacity(0.8),
							dark: Assets.Colors.black.opacity(0.4)
						)
					)
					.clipShape(.capsule)
					.transition(.opacity)
					.padding()
			}
		}
		.overlay(alignment: .bottomTrailing) {
			if self.store.currentMedia.isVideo {
				Button {
					self.store.send(.onTapSoundButton)
				} label: {
					Image(systemName: self.store.videoMuted ? "speaker.slash.fill" : "speaker.fill")
						.padding(8)
						.background(
							Assets.Colors.customReversedAdaptiveColor(
								self.colorScheme,
								light: Assets.Colors.lightDark,
								dark: Assets.Colors.dark
							)
						)
						.clipShape(.circle)
						.frame(width: 35, height: 35)
						.contentShape(.circle)
				}
				.fadeEffect()
				.padding()
			}
		}
		.task {
			await self.store.send(.task).finish()
		}
	}
}
