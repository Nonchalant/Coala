import Tagged

struct Thread {
    let id: Id

    typealias Id = Tagged<Thread, String>
}
