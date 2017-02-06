import UIKit

public protocol NotificationCenterProtocol {
  func post(_ descriptor: NotificationDescriptor, object: Any?)
  func addObserverTiedToLifetimeOfClass<Note: NotificationDescriptor>(_ observer: AnyObject, queue: OperationQueue?, using block: @escaping (Note) -> ())
  func addObserver<Note: NotificationDescriptor>(queue: OperationQueue?, using block: @escaping (Note) -> ()) -> Token
}

extension NotificationCenterProtocol {
  public func post(_ descriptor: NotificationDescriptor) {
    post(descriptor, object: nil)
  }
  
  public func addObserverTiedToLifetimeOfClass<Note: NotificationDescriptor>(_ observer: AnyObject, using block: @escaping (Note) -> ()) {
    return addObserverTiedToLifetimeOfClass(observer, queue: nil, using: block)
  }
  public func addObserver<Note: NotificationDescriptor>(using block: @escaping (Note) -> ()) -> Token {
    return addObserver(queue: nil, using: block)
  }
}

public protocol NotificationDescriptor {
  static var name: Notification.Name { get }
  init(notification: Notification)
  func post(to center: NotificationCenter, object: Any?)
}

extension NotificationDescriptor {
  public static var name: Notification.Name {
    return Notification.Name(rawValue: "\(Self.self).Notification")
  }
}

public class Token {
  
  let token: NSObjectProtocol
  let center: NotificationCenter
  init(token: NSObjectProtocol, center: NotificationCenter) {
    self.token = token
    self.center = center
  }
  
  deinit {
    center.removeObserver(token)
  }
}

public class NotificationManager: NotificationCenterProtocol {
  private static var tokenMap = NSMapTable<AnyObject, NSArray>(keyOptions: .weakMemory, valueOptions: .strongMemory)
  //We need to do this becuase maptable is basically broken from weak keys strong values. It doesn't actually release the values when keys get deinit. Calling remove all objects forces that release. If you have lots of notifications tie the Token instance to the view controller using the addObserver method
  private func cleanMapTable() {
    let localMap = NotificationManager.tokenMap.copy()
    NotificationManager.tokenMap.removeAllObjects()
    NotificationManager.tokenMap = localMap as! NSMapTable<AnyObject, NSArray>
  }
  static func tieLifetimeOf(token: Token, toClass: AnyObject) {
    var tokens = NSMutableArray()
    if let value = tokenMap.object(forKey: toClass), let existingTokens = value.mutableCopy() as? NSMutableArray {
      tokens = existingTokens
    }
    tokens.add(token)
    tokenMap.setObject(tokens, forKey: toClass)
  }
  
  internal let center: NotificationCenter
  
  public init(center: NotificationCenter) {
    self.center = center
  }
  
  public func post(_ descriptor: NotificationDescriptor, object: Any?) {
    
    descriptor.post(to: center, object: object)
  }
  
  public func addObserverTiedToLifetimeOfClass<Note: NotificationDescriptor>(_ observer: AnyObject, queue: OperationQueue?, using block: @escaping (Note) -> ()) {
    let token = addObserver(queue: queue, using: block)
    NotificationManager.tieLifetimeOf(token: token, toClass: observer)
  }
  
  public func addObserver<Note: NotificationDescriptor>(queue: OperationQueue?, using block: @escaping (Note) -> ()) -> Token {
    return Token(token: center.addObserver(forName: Note.name, object: nil, queue: queue, using: { note in
      block(Note(notification: note))
    }), center: center)
  }
}

public protocol EnumNotificationDescriptorTrait {
  init?(rawValue: String)
  var rawValue: String { get }
  static var name: Notification.Name { get }
}

extension EnumNotificationDescriptorTrait {
  public init(notification: Notification) {
    self = Self(rawValue: notification.userInfo!["value"] as! String)!
  }
  public func post(to center: NotificationCenter, object: Any?) {
    center.post(name: Self.name, object: object, userInfo: ["value": rawValue])
  }
}
