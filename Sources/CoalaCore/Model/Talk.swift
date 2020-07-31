import Foundation

struct Talk: Codable, Equatable {
    let member: Member
    let question: String
    let answer: String
}
