import ArgumentParser

public enum Command: String {
    case question
    case collect
    case post
}

extension Command: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument)
    }
}
