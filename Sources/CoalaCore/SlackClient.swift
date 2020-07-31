import Combine
import Foundation
import SlackKit

class SlackClient {

    private let dataStore = DataStore()
    private let slack = SlackKit()

    init(token: String) {
        slack.addWebAPIAccessWithToken(token)
    }
}

extension SlackClient {

    func fetchMembers(id: Channel.Id) -> AnyPublisher<[Member], Never> {
        return Future<[Member.Id], Never> { [weak self] promise in
            guard let me = self else {
                print("Unknown")
                promise(.success([]))
                return
            }

            me.slack.webAPI?.conversationsMembers(
                id: id.rawValue,
                success: { (ids, _) in
                    if let ids = ids, !ids.isEmpty {
                        let memberIds = ids.map(Member.Id.init(rawValue:))
                        promise(.success(memberIds))
                    } else {
                        promise(.success([]))
                    }
                },
                failure: { error in
                    print(error.localizedDescription)
                    promise(.success([]))
                }
            )
        }
        .flatMap { [weak self] ids -> AnyPublisher<[Member], Never> in
            guard let me = self else {
                print("Unknown")
                return Just([]).eraseToAnyPublisher()
            }

            return ids.publisher
                .flatMap { id in
                    me.fetchMember(id: id)
                }
                .collect()
                .map { members in
                    members.compactMap { $0 }
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    private func fetchMember(id: Member.Id) -> Future<Member?, Never> {
        return Future<Member?, Never> { [weak self] promise in
            guard let me = self else {
                print("Unknown")
                promise(.success(nil))
                return
            }

            me.slack.webAPI?.userInfo(
                id: id.rawValue,
                success: { user in
                    if !(user.isBot ?? false) {
                        promise(.success(Member(id: id, name: user.name ?? "", image: user.profile?.image192 ?? "")))
                    } else {
                        promise(.success(nil))
                    }
                },
                failure: { error in
                    print(error)
                    promise(.success(nil))
                }
            )
        }
    }
}

extension SlackClient {

    func questions(members: [Member]) -> AnyPublisher<Void, Never> {
        members.shuffled().prefix(3).publisher
            .flatMap { [weak self] member -> AnyPublisher<Question?, Never> in
                guard let me = self else {
                    print("Unknown")
                    return Just(nil).eraseToAnyPublisher()
                }

                return me.question(member: member).eraseToAnyPublisher()
            }
            .collect()
            .handleEvents(receiveOutput: { [weak self] questions in
                guard let me = self else { return }

                do {
                    let newQuestions = (try me.dataStore.get(key: .questions) ?? []) + questions.compactMap { $0 }
                    try me.dataStore.save(key: .questions, value: newQuestions)
                } catch let error {
                    print(error)
                }
            })
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private func question(member: Member) -> Future<Question?, Never> {
        let channel = "@\(member.name)"
        let pretext = "@\(member.name) さんに今日の質問です"

        return Future<Question?, Never> { [weak self] promise in
            guard let me = self else { return }

            guard let sentence = try? me.dataStore.get(key: .sentences)?.randomElement() else {
                promise(.success(nil))
                return
            }

            me.slack.webAPI?.sendMessage(
                channel: channel,
                text: "",
                parse: .full,
                attachments: [Attachment(attachment: ["pretext": pretext, "title": sentence])],
                success: { (thread, channelId) in
                    guard let thread = thread, let channelId = channelId else {
                        promise(.success(nil))
                        return
                    }

                    let question = Question(
                        channelId: Channel.Id(rawValue: channelId),
                        threadId: Thread.Id(rawValue: thread),
                        member: member,
                        question: sentence
                    )

                    me.slack.webAPI?.sendThreadedMessage(
                        channel: channel,
                        thread: thread,
                        text: "こちらのスレッドに回答をお願いします！",
                        success: { _ in
                            promise(.success(question))
                        },
                        failure: { error in
                            print(error)
                            promise(.success(nil))
                        }
                    )
                },
                failure: { error in
                    print(error)
                    promise(.success(nil))
                }
            )
        }
    }
}

extension SlackClient {

    func collectAnswers() -> AnyPublisher<Void, Never> {
        guard let questions = try? dataStore.get(key: .questions) else {
            print("No Questions")
            return Just(()).eraseToAnyPublisher()
        }

        return questions.publisher
            .flatMap { [weak self] question -> AnyPublisher<(Question, Talk)?, Never> in
                guard let me = self else {
                    print("Unknown")
                    return Just(nil).eraseToAnyPublisher()
                }

                return me.collectAnswer(question: question)
                    .map { answer in
                        guard let answer = answer else {
                            return nil
                        }

                        let talk = Talk(
                            member: question.member,
                            question: question.question,
                            answer: answer
                        )

                        return (question, talk)
                    }
                    .eraseToAnyPublisher()
            }
            .collect()
            .handleEvents(receiveOutput: { [weak self] elements in
                guard let me = self else { return }

                let (questions, talks) = elements.compactMap({ $0 }).reduce(into: ([Question](), [Talk]())) {
                    $0.0.append($1.0)
                    $0.1.append($1.1)
                }

                do {
                    let newTalks = (try me.dataStore.get(key: .talks) ?? []) + talks.compactMap { $0 }
                    try me.dataStore.save(key: .talks, value: newTalks)

                    let now = Date().timeIntervalSince1970

                    let newQuestions = (try me.dataStore.get(key: .questions) ?? [])
                        .filter { !questions.contains($0) }
                        .filter { question in
                            guard let timestamp = TimeInterval(question.threadId.rawValue) else {
                                return true
                            }

                            // 1週間以上未回答の質問は削除
                            return now - timestamp <= TimeInterval(7 * 24 * 60 * 60)
                        }

                    try me.dataStore.save(key: .questions, value: newQuestions)
                } catch let error {
                    print(error)
                }
            })
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private func collectAnswer(question: Question) -> Future<String?, Never> {
        return Future<String?, Never> { [weak self] promise in
            guard let me = self else { return }

            me.slack.webAPI?.conversationsReplies(
                id: question.channelId.rawValue,
                ts: question.threadId.rawValue,
                success: { (replies, _) in
                    guard let replies = replies, replies.count >= 3 else {
                        print("Not answered yet")
                        promise(.success(nil))
                        return
                    }

                    guard let reply = replies[2]["text"] as? String else {
                        promise(.success(nil))
                        return
                    }

                    me.slack.webAPI?.sendThreadedMessage(
                        channel: "@\(question.member.name)",
                        thread: question.threadId.rawValue,
                        text: "ありがとうございます！",
                        success: { _ in
                            promise(.success(reply))
                        },
                        failure: { error in
                            print(error)
                            promise(.success(reply))
                        }
                    )
                },
                failure: { error in
                    print(error)
                    promise(.success(nil))
                }
            )
        }
    }
}

extension SlackClient {

    func postTalks(id: Channel.Id) -> AnyPublisher<Void, Never> {
        guard let talks = try? dataStore.get(key: .talks) else {
            print("No talks")
            return Just(()).eraseToAnyPublisher()
        }

        return talks.shuffled().prefix(1).publisher
            .flatMap { [weak self] talk -> AnyPublisher<Talk?, Never> in
                guard let me = self else {
                    print("Unknown")
                    return Just(nil).eraseToAnyPublisher()
                }

                return me.postTalk(id: id, talk: talk).eraseToAnyPublisher()
            }
            .collect()
            .handleEvents(receiveOutput: { [weak self] talks in
                guard let me = self else { return }

                do {
                    let newTalks = (try me.dataStore.get(key: .talks) ?? [])
                        .filter { !talks.contains($0) }
                    try me.dataStore.save(key: .talks, value: newTalks)
                } catch let error {
                    print(error)
                }
            })
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private func postTalk(id: Channel.Id, talk: Talk) -> Future<Talk?, Never> {
        return Future<Talk?, Never> { [weak self] promise in
            guard let me = self else {
                print("Unknown")
                promise(.success(nil))
                return
            }

            me.slack.webAPI?.sendMessage(
                channel: id.rawValue,
                text: "今日もチームのみんなに聞いたことをシェアしますね。",
                parse: .full,
                blocks: [
                    SectionBlock(
                        text: TextComposition(
                            type: .markdown,
                            text: "今日もチームのみんなに聞いたことをシェアしますね。"
                        )
                    ),
                    SectionBlock(
                        text: TextComposition(
                            type: .markdown,
                            text: "@\(talk.member.name) さんに聞いてみました"
                        )
                    ),
                    SectionBlock(
                        text: TextComposition(
                            type: .markdown,
                            text: "*\(talk.question)*\n>>>\(talk.answer)"
                        ),
                        accessory: ImageElement(
                            imageURL: talk.member.image,
                            altText: talk.member.name
                        )
                    )
                ],
                success: { _ in
                    promise(.success(talk))
                },
                failure: { error in
                    print(error)
                    promise(.success(nil))
                }
            )
        }
    }
}
