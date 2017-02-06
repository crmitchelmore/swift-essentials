import Foundation
import CoreLocation

public enum SerializationError: Error {
  case missing(String)
  case invalid(String, Any)
}

precedencegroup SubscriptPrecedence {
  associativity: left
  higherThan: BitwiseShiftPrecedence
}

infix operator « : SubscriptPrecedence
infix operator «! : SubscriptPrecedence
infix operator «? : SubscriptPrecedence
infix operator «?! : SubscriptPrecedence

postfix operator »

public postfix func » (value: String) -> String {
  return value
}

public typealias JSONDict = Dictionary<String, Any>
public typealias JSONArray = Array<Any>

public protocol JSONInitializable {
  init?(any: Any) throws
}

extension Dictionary {
  public static func from(any: Any, withErrorMessage message: String = "") throws  -> JSONDict {
    guard let jsonDict = any as? JSONDict else {
      throw SerializationError.invalid("Invalid json dict \(message)", self)
    }
    return jsonDict
  }
}

extension Array {
  public static func from(any: Any, withErrorMessage message: String = "") throws -> JSONArray {
    guard let jsonArray = any as? JSONArray else {
      throw SerializationError.invalid("Invalid json array \(message)", self)
    }
    return jsonArray
  }
}

// JSON keys are always strings but we may want to use the keys as strong types in our code e.g. enums
public protocol DictKeyStringInitializable: JSONInitializable {
  init(string: String) throws
}

extension DictKeyStringInitializable {
  public init?(any: Any) throws {
    guard let string = any as? String else {
      throw SerializationError.invalid("Invalid key for DictKeyStringInitializable", any)
    }
    try self.init(string: string)
  }
}

fileprivate func getValueForKey(_ key: String, from dictionary: JSONDict) throws -> Any  {
  guard let value = dictionary[key] else {
    throw SerializationError.missing(key)
  }
  return value
}

//Basic (No forcing ! values because we don't have good defaults.)

public func « <B: JSONInitializable>(dictionary: JSONDict, key: String) throws -> B {
  let value = try getValueForKey(key, from: dictionary)
  
  guard let result = try B(any: value) else {
    throw SerializationError.invalid(key, value)
  }
  return result
}

//Return nil if key exists but no data or invalid data

public func «? <B: JSONInitializable>(dictionary: JSONDict, key: String) throws -> B? {
  let value = try getValueForKey(key, from: dictionary)
  return try B(any: value)
}

// Force nil for missing keys
public func «?! <B: JSONInitializable>(dictionary: JSONDict, key: String) throws -> B? {
  if let value: B? = try? dictionary«?key»  {
    return value
  }
  return nil
}

//Array cases


public func « <B: JSONInitializable>(dictionary: JSONDict, key: String) throws -> [B] {
  let value = try getValueForKey(key, from: dictionary)
  let array = try JSONArray.from(any: value, withErrorMessage: "Failed to convert \(key) to array")
  return try array.map {
    guard let b = try B(any: $0) else {
      throw SerializationError.invalid("Error processing array(\(key)) element", $0)
    }
    return b
  }
}

// Nillable arrays
public func «? <B: JSONInitializable>(dictionary: JSONDict, key: String) throws -> [B]? {
  do {
    return try dictionary«key»
  } catch let error as SerializationError {
    switch error {
    case .invalid(_, _): return nil
    default: throw error
    }
  }
}

// The case where you want to force an empty array if the key is missing or invalid data

public func «! <B: JSONInitializable>(dictionary: JSONDict, key: String) throws -> [B] {
  let result: [B]? = (try? dictionary«?key»).flatMap { $0 }
  return result ?? []
}

//Dictionary Cases

public func « <K: DictKeyStringInitializable, V: JSONInitializable>(dictionary: JSONDict, key: String) throws -> [K: V] {
  let value = try getValueForKey(key, from: dictionary)
  let dict = try JSONDict.from(any: value,  withErrorMessage: "Failed to convert \(key) to dictionary")
  
  var results: [K: V] = [:]
  try dict.forEach { k, v in results[try K(string: k)] = try V(any: v) }
  return results
}

public func «? <K: DictKeyStringInitializable, V: JSONInitializable>(dictionary: JSONDict, key: String) throws -> [K: V]? {
  do {
    return try dictionary«key»
  } catch let error as SerializationError {
    switch error {
    case .invalid(_, _): return nil
    default: throw error
    }
  }
}

public func «! <K: DictKeyStringInitializable, V: JSONInitializable>(dictionary: JSONDict, key: String) throws -> [K: V] {
  let result: [K: V]? = (try? dictionary«?key»).flatMap { $0 }
  return result ?? [:]
}

//Basic type implementations

extension Int: JSONInitializable {
  public init?(any value: Any) {
    if let int = value as? Int {
      self.init(int)
    } else {
      guard let string = value as? String else { return nil }
      self.init(string)
    }
  }
}

extension Double: JSONInitializable {
  public init?(any value: Any) {
    if let double = value as? Double {
      self.init(double)
    } else if let int = value as? Int {
      self.init(int)
    } else {
      guard let string = value as? String else { return nil }
      self.init(string)
    }
  }
}

extension String: DictKeyStringInitializable {
  
  public init(string: String) throws {
    guard let s = String(string) else {
      throw SerializationError.invalid("Not happening", string)
    }
    self = s
  }
  
  public init?(any value: Any) {
    guard let string = value as? String else { return nil }
    self.init(string)
  }
}

extension DateFormatter {
  convenience init(format: String) {
    self.init()
    dateFormat = format
    locale = Locale(identifier: "en_GB_POSIX")
    timeZone = TimeZone(identifier: "GMT")
  }
}

extension Date: JSONInitializable {
  fileprivate static let dateFormatters = [DateFormatter(format: "yyyy-MM-dd'T'HH:mm:ssZZZZ"), DateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ")]
  public init?(any value: Any) throws {
    if let string = String(any: value) {
      let dates = Date.dateFormatters.flatMap { $0.date(from: string) }
      guard let date = dates.first else {
        throw SerializationError.invalid("No date formatted matched", string)
      }
      self.init(timeIntervalSince1970: date.timeIntervalSince1970)
    } else if let interval = Double(any: value) {
      self.init(timeIntervalSince1970: interval)
    } else {
      throw SerializationError.invalid("Couldn't convert to date", value)
    }
  }
}

extension Bool: JSONInitializable {
  public init?(any value: Any) throws {
    if let bool = value as? Bool {
      self = bool
    } else if let string = value as? String {
      if let num = Int(string), (num == 1 || num == 0) {
        self = num != 0
      } else if string.lowercased() == "true" || string.lowercased() == "false" {
        self = string.lowercased() == "true"
      } else {
        throw SerializationError.invalid("Value not a valid bool string input", string)
      }
    } else if let num = value as? Int, (num == 1 || num == 0) {
      self = num != 0
    } else {
      throw SerializationError.invalid("Value couldn't be converted to bool", value)
    }
  }
}

//Expects a dictionary with keys: longitude and latitude with doubles as values
extension CLLocationCoordinate2D: JSONInitializable {
  public init?(any: Any) throws {
    let json = try JSONDict.from(any: any, withErrorMessage: "\(any) could not be converted to coordinate dictionary")
    let latitude: Double = try json«"latitude"»
    let longitude: Double = try json«"longitude"»
    self = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

