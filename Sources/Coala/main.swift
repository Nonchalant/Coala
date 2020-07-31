import Foundation
import CoalaCore

do {
    let arguments = try Arguments.parse()
    let worker = Worker(token: arguments.token, channelId: arguments.channelId)

    switch arguments.command {
    case .question:
        worker.question()
    case .collect:
        worker.collect()
    case .post:
        worker.post()
    }

    RunLoop.main.run()
} catch let error {
    print(error)
}
