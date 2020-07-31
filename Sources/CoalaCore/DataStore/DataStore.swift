import Foundation
import PathKit

struct DataStore {

    func get<T: Decodable>(key: DataStoreKey<T>) throws -> T? {
        guard Path(key.path).exists else {
            return nil
        }

        let data = try Path(key.path).read()
        return try JSONDecoder().decode(T.self, from: data)
    }

    func save<T: Encodable>(key: DataStoreKey<T>, value: T) throws {
        let data = try JSONEncoder().encode(value)
        try Path(key.path).write(data)
    }
}
