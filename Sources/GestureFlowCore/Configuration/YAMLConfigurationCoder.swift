import Foundation
import Yams

enum YAMLConfigurationCoder {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let yaml = String(decoding: data, as: UTF8.self)
        return try YAMLDecoder().decode(type, from: yaml)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let yaml = try YAMLEncoder().encode(value)
        guard let data = yaml.data(using: .utf8) else {
            throw YAMLCodingError.failedToEncodeUTF8
        }
        return data
    }
}

enum YAMLCodingError: Error {
    case failedToEncodeUTF8
}
