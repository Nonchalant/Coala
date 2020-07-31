import ArgumentParser
import Tagged

public struct Channel {
    let id: Id

    public typealias Id = Tagged<Channel, String>
}

extension Channel.Id: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument)
    }
}
