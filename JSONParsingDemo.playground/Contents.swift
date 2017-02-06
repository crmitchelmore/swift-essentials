import Swisential
import CoreLocation

//Model

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



//Usage

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

//Sample json referenced
/**** //Note: there is no "cheatCode" key in the json, usually this would cause a failure but we marked cheatCode as coerced ?! so it will be set to nil and no error generated.
 Try modifying the json in resources of this demo to see error messages
 */
var fileUrl = Bundle.main.url(forResource: "user", withExtension: "json")!
let data = try? Data(contentsOf: fileUrl)
if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) {
  do {
    let user = try User(json)
    dump(user)
  } catch {
    print(error)
  }
}



