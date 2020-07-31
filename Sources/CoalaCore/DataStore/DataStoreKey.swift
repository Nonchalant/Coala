struct DataStoreKey<T: Codable> {
    let path: String
}

extension DataStoreKey {
    static var sentences: DataStoreKey<[String]> { .init(path: "./sentences.json") }
    static var questions: DataStoreKey<[Question]> { .init(path: "./questions.json") }
    static var talks: DataStoreKey<[Talk]> { .init(path: "./talks.json") }
}
