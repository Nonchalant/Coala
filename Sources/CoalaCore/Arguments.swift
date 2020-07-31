import ArgumentParser

public struct Arguments: ParsableCommand {
    @Argument(help: "Command")
    public var command: Command

    @Argument(help: "Slack App Token")
    public var token: String

    @Argument(help: "Slack Channel ID")
    public var channelId: Channel.Id

    public init() {}
}
