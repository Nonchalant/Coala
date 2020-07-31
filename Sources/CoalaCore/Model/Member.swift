import Foundation
import Tagged

struct Member: Codable, Equatable {
    let id: Id
    let name: String
    let image: String

    typealias Id = Tagged<Member, String>
}
