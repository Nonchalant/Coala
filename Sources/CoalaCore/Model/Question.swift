import Foundation

struct Question: Codable, Equatable {
    let channelId: Channel.Id
    let threadId: Thread.Id
    let member: Member
    let question: String
}
