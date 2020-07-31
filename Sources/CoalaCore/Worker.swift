import Combine
import Foundation

public class Worker {

    private let client: SlackClient
    private let channelId: Channel.Id

    private var cancellables: [AnyCancellable] = []

    public init(token: String, channelId: Channel.Id) {
        self.client = SlackClient(token: token)
        self.channelId = channelId
    }

    public func question() {
        client.fetchMembers(id: channelId)
            .flatMap { [weak self] members -> AnyPublisher<Void, Never> in
                guard let me = self else {
                    print("Unknown")
                    return Just(()).eraseToAnyPublisher()
                }

                return me.client.questions(members: members)
            }
            .sink { _ in
                exit(0)
            }
            .store(in: &cancellables)
    }

    public func collect() {
        client.collectAnswers()
            .sink { _ in
                exit(0)
            }
            .store(in: &cancellables)
    }

    public func post() {
        client.postTalks(id: channelId)
            .sink { _ in
                exit(0)
            }
            .store(in: &cancellables)
    }
}
