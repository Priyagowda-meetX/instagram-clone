import Foundation
import Shared

public protocol UserBaseRepository: Sendable {
	var currentUserId: String? { get async }
	func profile(of userId: String) async -> AsyncStream<User>
	func followersCount(of userId: String) async -> AsyncStream<Int>
	func followingsCount(of userId: String) async -> AsyncStream<Int>
	func isFollowed(followerId: String, userId: String) async throws -> Bool
	func follow(followedToId: String, followerId: String?) async throws -> Void
	func unFollow(unFollowedId: String, unFollowerId: String?) async throws -> Void
	func followers(of userId: String) async -> AsyncStream<[Shared.User]>
	func followings(of userId: String) async throws -> [Shared.User]
	func followingStatus(of userId: String, followerId: String) async -> AsyncStream<Bool>
	func removeFollower(of userId: String) async throws -> Void
	func updateUser(email: String?, avatarUrl: String?, username: String?, fullName: String?, pushToken: String?) async throws -> Void
}

public protocol PostsBaseRepository: Sendable {
	func postsAmount(of userId: String) async -> AsyncStream<Int>
	func createPost(postId: String, caption: String, mediaJsonString: String) async throws -> Post?
	func getPage(offset: Int, limit: Int, onlyReels: Bool) async throws -> [Post]
	func getPostLikersInFollowings(postId: String, offset: Int, limit: Int) async throws -> [Shared.User]
	func likesOfPost(postId: String, post: Bool) async -> AsyncStream<Int>
	func postCommentsCount(postId: String) async -> AsyncStream<Int>
	func isLiked(postId: String, userId: String?, post: Bool) async -> AsyncStream<Bool>
	func postAuthorFollowingStatus(postAuthorId: String, userId: String?) async -> AsyncStream<Bool>
	func likePost(postId: String, post: Bool) async throws -> Void
	func deletePost(postId: String) async throws -> Void
	func updatePost(postId: String, caption: String) async throws -> Post?
	func postsOf(userId: String?) async -> AsyncStream<[Post]>
	func commentsOf(postId: String) async -> AsyncStream<[Shared.Comment]>
	func createComment(postId: String, userId: String, content: String, repliedToCommentId: String?) async throws -> Void
	func repliedCommentsOf(commentId: String) async -> AsyncStream<[Shared.Comment]>
	func deleteComment(commentId: String) async throws -> Void
}

public protocol ChatsBaseRepository: Sendable {
	func chatsOf(userId: String) async -> AsyncStream<[ChatInbox]>
	func deleteChat(chatId: String, userId: String) async throws -> Void
	func createChat(userId: String, participantId: String) async throws -> Void
	func messagesOf(chatId: String) async -> AsyncStream<[Message]>
	func sendMessage(chatId: String, sender: Shared.User, receiver: Shared.User, message: Message, postAuthor: PostAuthor?) async throws -> Void
	func deleteMessage(messageId: String) async throws -> Void
	func readMessage(messageId: String) async throws -> Void
	func editMessage(oldMessage: Message, newMessage: Message) async throws -> Void
}

public protocol SearchBaseRepository: Sendable {
	func searchUsers(limit: Int, offset: Int, query: String, userId: String?, excludedUserIds: [String]) async throws -> [Shared.User]
}

public protocol DatabaseClient: UserBaseRepository, PostsBaseRepository, SearchBaseRepository, ChatsBaseRepository {}
