import PlaygroundSupport
import Swisential
import CoreLocation

// SCROLL TO LINE 100. THIS IS JUST BOILER PLATE FOR USER PARSING

PlaygroundPage.current.needsIndefiniteExecution = true

struct User {
  let name: String
  let nickName: String?
  let cheatCode: String?
  let dateOfBirth: Date?
  let notes: [String]
  let team: Team
  let playerAbilities: [GameObjective: SkillInfo]
  let itemsCounts: [String: Int]
}

enum GameObjective: String {
  case war, trade, fun
}

struct Team {
  let name: String
  let location: CLLocationCoordinate2D
  let objective: GameObjective
}

struct SkillInfo {
  let level: Int
  let score: Double
}

extension User: JSONInitializable {
  
  // Additional init for convinience of getting a non nil inferred type
  init(_ any: Any) throws {
    guard let user = try User(any: any) else {
      throw SerializationError.invalid("Failed to build user", any)
    }
    self = user
  }
  
  init?(any: Any) throws {
    let json = try JSONDict.from(any: any, withErrorMessage: "Couldn't find base dictionary")
    try name = json«"name"»
    try nickName = json«?"nickName"»
    try cheatCode = json«?!"cheatCode"»
    try dateOfBirth = json«?"dateOfBirth"»
    try notes = json«"notes"»
    try team = json«"team"»
    try playerAbilities = json«"playerAbilities"»
    try itemsCounts = json«"itemsCounts"»
  }
}

// Most cases are just declaring the mapping of each struct
extension Team: JSONInitializable {
  init?(any: Any) throws {
    let json = try JSONDict.from(any: any, withErrorMessage: "Couldn't find team dict")
    try name = json«"name"»
    try location = json«"location"»
    try objective = json«"objective"»
  }
}

extension SkillInfo: JSONInitializable {
  init?(any: Any) throws {
    let json = try JSONDict.from(any: any, withErrorMessage: "Couldn't find skill info dictionary")
    try level = json«"level"»
    try score = json«"score"»
  }
}

// If there are enums they can be mapped and then used anywhere you like
extension GameObjective: DictKeyStringInitializable, JSONInitializable {
  public init(string: String) throws {
    guard let value = GameObjective(rawValue: string) else {
      throw SerializationError.invalid("TeamObjective Enum key", string)
    }
    self = value
  }
  
  public init?(any: Any) {
    guard let string = any as? String else { return nil }
    self.init(rawValue: string)
  }
}










extension User {
  
  static func withId(_ id: String) -> Resource<User> {
    let path = "users/\(id).json"
    return Resource<User>(path: path) {
      try User($0)
    }
  }
  
  static func findUsersWithAbility(_ ability: GameObjective, levelOver: Int) -> Resource<[User]> {
    let path = "search"
    let parameters = [
      "post params here": "default to json encoded",
      "ability": ability.rawValue,
      "level": levelOver
      ] as AnyObject
    
    return Resource<[User]>(method: .post(parameters), path: path, headerFields: ["request specific": "header field"], parameters: ["url": "parameters", "go": "here"], cachePolicy: .reloadIgnoringCacheData) {
      let array = try JSONArray.from(any: $0, withErrorMessage: "Couldn't make json array")
      return try array.map { try User($0) }
    }
  }
  
}

//Generate a local url to use as base api url
var fileUrl = Bundle.main.url(forResource: "users/102", withExtension: "json")
let baseUrl = fileUrl?.deletingLastPathComponent().deletingLastPathComponent()

let basicApi: APIProtocol = API(baseUrl: baseUrl!.absoluteString)
let resource = User.withId("102")
basicApi.load(resource: resource) { result in
  if case .success(let user) = result {
    dump(user)
  } else if case .error(let error) = result {
    dump(error)
  }
}



// Won't actually return results because there's no way to post to local files system
let api: APIProtocol = API(baseUrl: baseUrl!.absoluteString, headerFields: ["Authorization": "Some tricky token", "Accept": "application/json"])
api.load(resource: User.findUsersWithAbility(.trade, levelOver: 4)) { result in
  if case .success(let users) = result {
    dump(users)
  }
}
