/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public enum AirshipJSON: Codable, Equatable, Sendable, Hashable {
    public static let defaultEncoder = JSONEncoder()
    public static let defaultDecoder = JSONDecoder()
    
    case string(String)
    case number(Double)
    case object([String: AirshipJSON])
    case array([AirshipJSON])
    case bool(Bool)
    case null

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let array): try container.encode(array)
        case .object(let object): try container.encode(object)
        case .number(let number): try container.encode(number)
        case .string(let string): try container.encode(string)
        case .bool(let bool): try container.encode(bool)
        case .null: try container.encodeNil()
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let object = try? container.decode([String: AirshipJSON].self) {
            self = .object(object)
        } else if let array = try? container.decode([AirshipJSON].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw AirshipErrors.error("Invalid JSON")
        }
    }

    public func unWrap() -> Any? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return nil
        case .object(let value):
            var dict: [String: Any] = [:]
            value.forEach {
                dict[$0.key] = $0.value.unWrap()
            }
            return dict
        case .array(let value):
            var array: [Any] = []
            value.forEach {
                if let item = $0.unWrap() {
                    array.append(item)
                }
            }
            return array
        }
    }

    public static func from(
        json: String?,
        decoder: JSONDecoder = AirshipJSON.defaultDecoder
    ) throws -> AirshipJSON {
        guard let json = json else {
            return .null
        }
        
        guard let data = json.data(using: .utf8) else {
            throw AirshipErrors.error("Invalid encoding: \(json)")
        }
        
        return try decoder.decode(AirshipJSON.self, from: data)
    }
    
    public static func from(
        data: Data?,
        decoder: JSONDecoder = AirshipJSON.defaultDecoder
    ) throws -> AirshipJSON {
        guard let data = data else {
            return .null
        }
        
        return try decoder.decode(AirshipJSON.self, from: data)
    }
    
    public static func wrap(_ value: Any?) throws -> AirshipJSON {
        guard let value = value else {
            return .null
        }

        if let string = value as? String {
            return .string(string)
        }

        if let number = value as? NSNumber {
            guard CFBooleanGetTypeID() == CFGetTypeID(number) else {
                return .number(number.doubleValue)
            }
            return .bool(number.boolValue)
        }

        if let bool = value as? Bool {
            return .bool(bool)
        }

        if let number = value as? Double {
            return .number(number)
        }

        if let number = value as? NSNumber {
            return .number(number.doubleValue)
        }

        if let array = value as? [Any?] {
            let mapped: [AirshipJSON] = try array.map { child in
                try wrap(child)
            }

            return .array(mapped)
        }

        if let object = value as? [String: Any?] {
            let mapped: [String: AirshipJSON] = try object.mapValues { child in
                try wrap(child)
            }

            return .object(mapped)
        }

        throw AirshipErrors.error("Invalid JSON \(value)")
    }
    
    public func toData(encoder: JSONEncoder = AirshipJSON.defaultEncoder) throws -> Data {
        return try encoder.encode(self)
    }
    
    public func toString(encoder: JSONEncoder = AirshipJSON.defaultEncoder) throws -> String {
        return String(
            decoding: try encoder.encode(self),
            as: UTF8.self
        )
    }
}
