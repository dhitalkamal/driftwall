import Foundation

extension KeyedDecodingContainer {
    // decodes a field, returning nil when the key is missing or holds a value this build
    // cannot decode (unknown enum case, wrong type). callers apply the field's own default,
    // so one bad field never discards the rest of the config.
    func decodeLenient<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        // try? flattens the optional from decodeIfPresent (swift 5), so this is T?, not T??.
        try? decodeIfPresent(type, forKey: key)
    }
}
