import AppUI
import ComposableArchitecture
import Foundation
import InstaBlocks
import InstagramBlocksUI
import InstagramClient
import MediaPickerFeature
import PostPreviewFeature
import Shared
import SwiftUI
import YPImagePicker
import CommentsFeature

enum ProfileTab: Hashable {
	case posts
	case mentionedPosts
	case followers
	case followings
}

@Reducer
public struct UserProfileReducer {
	@Reducer(state: .equatable)
	public enum Destination {
		case profileSettings(UserProfileSettingsReducer)
		case profileAddMedia(UserProfileAddMediaReducer)
		case mediaPicker(MediaPickerReducer)
		case userStatistics(UserStatisticsReducer)
		case profileEdit(UserProfileEditReducer)
		case userProfilePosts(UserProfilePostsReducer)
		case comments(CommentsReducer)
	}

	public init() {}
	@ObservableState
	public struct State: Equatable, Identifiable {
		let authenticatedUserId: String
		let profileUserId: String
		var profileUser: User?
		var profileHeader: UserProfileHeaderReducer.State
		var activeTab: ProfileTab = .posts
		var props: UserProfileProps?
		var smallPosts: IdentifiedArrayOf<PostSmallReducer.State> = []
		@Presents var destination: Destination.State?
		var showBackButton: Bool
		public init(
			authenticatedUserId: String,
			profileUser: User? = nil,
			profileUserId: String,
			showBackButton: Bool = false,
			props: UserProfileProps? = nil
		) {
			self.authenticatedUserId = authenticatedUserId
			self.profileUser = profileUser
			self.profileUserId = profileUserId
			self.showBackButton = showBackButton
			self.props = props
			self.profileHeader = UserProfileHeaderReducer.State(profileUserId: profileUserId, isOwner: authenticatedUserId == profileUserId, profileUser: profileUser)
		}

		var isOwner: Bool {
			authenticatedUserId == profileUserId
		}

		public var id: String {
			profileUserId
		}
	}

	public indirect enum Action: BindableAction {
		case destination(PresentationAction<Destination.Action>)
		case binding(BindingAction<State>)
		case onTapLogoutButton
		case task
		case profileUser(User)
		case profileHeader(UserProfileHeaderReducer.Action)
		case smallPostsOfUser(blocks: [PostSmallBlock])
		case onTapSettingsButton
		case onTapAddMediaButton
		case onTapMoreButton
		case onTapBackButton
		case onTapSponsoredPromoAction(URL?)
		case onTapSmallPost(postId: String)
		case smallPosts(IdentifiedActionOf<PostSmallReducer>)
		case onTapLikePost(postId: String)
		case onTapCommentButton(post: PostSmallBlock)
		case delegate(Delegate)
		public enum Delegate {
			case routeToFeed(scrollToTop: Bool)
		}
	}

	@Dependency(\.instagramClient.authClient) var authClient
	@Dependency(\.instagramClient.databaseClient) var databaseClient

	public var body: some ReducerOf<Self> {
		BindingReducer()
		Scope(state: \.profileHeader, action: \.profileHeader) {
			UserProfileHeaderReducer()
		}
		Reduce {
			state,
				action in
			switch action {
			case .binding:
				return .none
			case .destination(.dismiss):
				return .none
			case .destination(.presented(.mediaPicker(.delegate(.onTapCancelButton)))):
				state.destination = nil
				return .none
			case .destination(.presented(.mediaPicker(.delegate(.createPostPopToRoot)))):
				state.destination = nil
				return .send(.delegate(.routeToFeed(scrollToTop: true)))
			case let .destination(.presented(.profileAddMedia(.delegate(.onTapAddMediaButton(mediaType))))):
				let isReels = mediaType == .reels
				state.destination = .mediaPicker(MediaPickerReducer.State(pickerConfiguration: MediaPickerView.Configuration(maxItems: 10, reels: isReels)))
				return .none
			case .destination:
				return .none
			case .onTapLogoutButton:
				return .run { _ in
					try await authClient.logOut()
				}
			case .task:
				return .run { [profileUserId = state.profileUserId] send in
					async let profileUser: Void = {
						for await user in await databaseClient.profile(profileUserId) {
							await send(.profileUser(user))
						}
					}()
					async let postsOfUser: Void = {
						for await posts in await databaseClient.postsOf(profileUserId) {
							await send(.smallPostsOfUser(blocks: posts.map { $0.toPostSmallBlock() }), animation: .snappy)
						}
					}()
					_ = await (profileUser, postsOfUser)
				}
			case let .profileUser(user):
				state.profileUser = user
				return .none
			case let .profileHeader(.delegate(.onTapStatistics(tabIndex))):
				guard let profileUser = state.profileUser else {
					return .none
				}
				guard tabIndex > 0 else {
					state.destination = .userProfilePosts(
						UserProfilePostsReducer.State(
							profileUserId: state.profileUserId
						)
					)
					return .none
				}
				guard let selectedTab = UserStatisticsTab(rawValue: tabIndex) else {
					return .none
				}
				let userStatisticsState = UserStatisticsReducer.State(authUserId: state.authenticatedUserId, user: profileUser, selectedTab: selectedTab)
				state.destination = .userStatistics(userStatisticsState)
				return .none
			case .profileHeader(.delegate(.onTapEditProfileButton)):
				guard let user = state.profileUser else {
					return .none
				}
				state.destination = .profileEdit(UserProfileEditReducer.State(user: user))
				return .none
			case .profileHeader:
				return .none
			case let .smallPostsOfUser(blocks):
				for smallBlock in blocks.reversed() {
					if state.smallPosts[id: smallBlock.id] == nil {
						let smallBlockState = PostSmallReducer.State(
							block: smallBlock,
							isOwner: state.authenticatedUserId == smallBlock.author.id,
							isLiked: false
						)
						state.smallPosts.insert(smallBlockState, at: 0)
					}
				}
				var removedBlockIds: [String] = []
				let blockIds = blocks.map(\.id)
				for smallPost in state.smallPosts {
					if !blockIds.contains(smallPost.id) {
						removedBlockIds.append(smallPost.id)
					}
				}
				state.smallPosts.removeAll(where: { removedBlockIds.contains($0.id) })
				return .none
			case .onTapSettingsButton:
				state.destination = .profileSettings(UserProfileSettingsReducer.State())
				return .none
			case .onTapAddMediaButton:
				state.destination = .profileAddMedia(UserProfileAddMediaReducer.State())
				return .none
			case .onTapMoreButton:
				return .none
			case .onTapBackButton:
				return .run { _ in
					@Dependency(\.dismiss) var dismiss
					await dismiss()
				}
			case let .onTapSponsoredPromoAction(url):
				guard let url else {
					return .none
				}
				return .run { _ in
					@Dependency(\.openURL) var openURL
					await openURL(url)
				}
				.debounce(id: "Open_Sponsored_Promo", for: .milliseconds(300), scheduler: DispatchQueue.main)
			case let .onTapSmallPost(postId):
				state.destination = .userProfilePosts(
					UserProfilePostsReducer.State(
						profileUserId: state.profileUserId,
						scrollTo: postId
					)
				)
				return .none
			case .delegate:
				return .none
			case .smallPosts:
				return .none
			case let .onTapCommentButton(post):
				state.destination = .comments(CommentsReducer.State(post: .postSmall(post), currentUserId: state.authenticatedUserId))
				return .none
			case let .onTapLikePost(postId):
				return .run { _ in
					try await databaseClient.likePost(postId, true)
				}
			}
		}
		.ifLet(\.$destination, action: \.destination) {
			Destination.body
		}
		.forEach(\.smallPosts, action: \.smallPosts) {
			PostSmallReducer()
		}
	}
}

public struct UserProfileView: View {
	@Bindable var store: StoreOf<UserProfileReducer>
	@Environment(\.textTheme) var textTheme
	private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
	public init(store: StoreOf<UserProfileReducer>) {
		self.store = store
	}

	public var body: some View {
		VStack {
			ScrollView {
				appBar()
				userProfileHeader()
				posts()
			}
			.scrollIndicators(.hidden)
		}
		.coverStatusBar()
		.sheet(
			item: $store.scope(
				state: \.destination?.profileSettings,
				action: \.destination.profileSettings
			)
		) { profileSettingsStore in
			UserProfileSettingsView(store: profileSettingsStore)
				.presentationDetents([.height(240)])
				.presentationDragIndicator(.visible)
				.padding(.horizontal, AppSpacing.sm)
		}
		.sheet(
			item: $store.scope(
				state: \.destination?.profileAddMedia,
				action: \.destination.profileAddMedia
			)
		) { profileAddMediaStore in
			UserProfileAddMediaView(store: profileAddMediaStore)
				.presentationDetents([.height(280)])
				.presentationDragIndicator(.visible)
				.padding(.horizontal, AppSpacing.sm)
		}
		.navigationDestination(
			item: $store.scope(
				state: \.destination?.userStatistics,
				action: \.destination.userStatistics
			)
		) { userStatisticsStore in
			UserStatisticsView(store: userStatisticsStore)
		}
		.navigationDestination(
			item: $store.scope(
				state: \.destination?.mediaPicker,
				action: \.destination.mediaPicker
			)
		) { mediaPickerStore in
			MediaPicker(store: mediaPickerStore)
		}
		.overlay(alignment: .bottom) {
			sponsoredPromoFloatingAction()
		}
		.toolbar(.hidden, for: .navigationBar)
		.task {
			await store.send(.task).finish()
		}
	}

	@ViewBuilder
	private func sponsoredPromoFloatingAction() -> some View {
		if case let .navigateToSponsor(sponsorAction) = store.props?.promoBlockAction {
			Button {
				store.send(.onTapSponsoredPromoAction(URL(string: sponsorAction.promoUrl)))
			} label: {
				PromoFloatingAction(
					url: sponsorAction.promoUrl,
					promoImageUrl: sponsorAction.promoPreviewImageUrl,
					title: "Learn more",
					subTitle: "Go to website"
				)
				.contentShape(.rect)
			}
			.scaleEffect()
			.padding()
			.transition(.move(edge: .bottom))
		}
	}

	@ViewBuilder
	private func appBar() -> some View {
		AppNavigationBar(
			title: store.profileUser?.displayUsername ?? "",
			backButtonAction: store.showBackButton ? {
				store.send(.onTapBackButton)
			} : nil,
			actions: store.isOwner ? [
				AppNavigationBarTrailingAction(icon: .asset(Assets.Icons.setting.imageResource)) {
					store.send(.onTapSettingsButton)
				},
				AppNavigationBarTrailingAction(icon: .asset(Assets.Icons.addButton.imageResource)) {
					store.send(.onTapAddMediaButton)
				},
			] : [AppNavigationBarTrailingAction(icon: .system("ellipsis")) {
				store.send(.onTapMoreButton)
			}]
		)
		.padding(.horizontal, AppSpacing.md)
	}

	@ViewBuilder
	private func userProfileHeader() -> some View {
		UserProfileHeaderView(store: store.scope(state: \.profileHeader, action: \.profileHeader))
			.padding(AppSpacing.md)
			.navigationDestination(
				item: $store.scope(state: \.destination?.profileEdit, action: \.destination.profileEdit)
			) { profileEditStore in
				UserProfileEditView(store: profileEditStore)
			}
	}

	@ViewBuilder
	private func posts() -> some View {
		LazyVGrid(columns: columns, spacing: 2, pinnedViews: [.sectionHeaders]) {
			Section {
				ForEach(store.scope(state: \.smallPosts, action: \.smallPosts)) { smallPostStore in
					Button {
						store.send(.onTapSmallPost(postId: smallPostStore.id))
					} label: {
						PostSmallView<EmptyView>(
							store: smallPostStore,
							pinned: false
						)
						.frame(height: 140)
					}
					.fadeEffect()
					.contextMenu {
						Button {
							store.send(.onTapLikePost(postId: smallPostStore.id))
						} label: {
							Label(smallPostStore.isLiked ? "Unlike" : "Like", systemImage: smallPostStore.isLiked ? "heart.fill" : "heart")
						}
						Button {
							store.send(.onTapCommentButton(post: smallPostStore.block))
						} label: {
							Label("Comments", systemImage: "message")
						}
						
						Button {
							
						} label: {
							Label(smallPostStore.isOwner ? "Share post" : "View UserProfile", systemImage: smallPostStore.isOwner ? "location" : "person.circle")
						}
						
						Button {
							
						} label: {
							Label("Options", systemImage: "ellipsis")
						}
					} preview: {
						PostPreview(block: .postSmall(smallPostStore.block))
							.frame(idealWidth: 400, idealHeight: 400 * 1.2)
							.frame(minWidth: 320, minHeight: 320 * 1.2)
					}
				}
			} header: {
				VStack(spacing: 0) {
					ScrollTabBarView(selection: $store.activeTab) {
						AppUI.TabItem(ProfileTab.posts) {
							Image(systemName: "squareshape.split.3x3")
						}
						AppUI.TabItem(ProfileTab.mentionedPosts) {
							Image(systemName: "person")
						}
					}
				}
				.padding(.bottom, 40)
			}
		}
		.padding(.bottom, 48)
		.navigationDestination(
			item: $store.scope(
				state: \.destination?.userProfilePosts,
				action: \.destination.userProfilePosts
			)
		) { userProfilePostsStore in
			UserProfilePostsView(store: userProfilePostsStore)
		}
		.sheet(
			item: $store.scope(
				state: \.destination?.comments,
				action: \.destination.comments
			)
		) { commentsStore in
			CommentsView(store: commentsStore)
				.presentationDetents([.medium, .large])
				.presentationBackground(.regularMaterial)
		}
	}
}
