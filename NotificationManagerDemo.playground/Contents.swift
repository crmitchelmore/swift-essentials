import PlaygroundSupport
import Swisential
PlaygroundPage.current.needsIndefiniteExecution = true



// Defining notifications works well if you have a heirachy underwhich you group notifications. It's possible to map your, third party, and even system notifications in to this structure but it's not as clean. In the simple case of notification with no data, just defining an enum is enough to get all behaviour

struct AppNameNotifications {
  
  
  // Simple case enum notifications (must be string enums and conform to these protocols to get notificaiton behaviour)
  enum MediaDownload: String, NotificationDescriptor, EnumNotificationDescriptorTrait {
    case noData, success, failed
  }
  
  
  // Enum based notifications with associated values
  enum Posts: NotificationDescriptor {
    case updated(numberOfItems: Int)
    init(notification: Notification) {
      self = .updated(numberOfItems: notification.userInfo!["numItems"] as! Int)
    }
    internal func post(to center: NotificationCenter, object: Any?) {
      if case .updated(let numberOfItems) = self {
        center.post(name: Posts.name, object: object, userInfo: ["numItems": numberOfItems])
      }
    }
  }
  
  //Mapping system notifications to be observed
  struct UIApplication {
    struct DidBecomeActive: NotificationDescriptor {
      static let name = NSNotification.Name.UIApplicationDidBecomeActive
      init(notification: Notification) {}
      internal func post(to center: NotificationCenter, object: Any?) {
        fatalError()
      }
    }
  }
  
  struct UIKeyboard {
    struct WillShow: NotificationDescriptor {
      static let name = NSNotification.Name.UIKeyboardWillShow
      let keyboardSize: CGSize?
      init(notification: Notification) {
        keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey]! as AnyObject).cgRectValue.size
      }
      internal func post(to center: NotificationCenter, object: Any?) {
        fatalError()
      }
    }
  }
}


// Listening to notifications. Note, the closure must specify the type of notification so the observation key can be inferred
// There is no need to add/remove the observer from the vc, this is managed automatically by the lifetime of the class.

class SomeVC: UIViewController {
  
  var notificationManager: NotificationManager!
  
  func addObservers() {
    notificationManager.addObserverTiedToLifetimeOfClass(self) { (note: AppNameNotifications.MediaDownload) in
      switch note {
      case .success:
        print("Success")
      case .noData:
        print("No Data")
      case .failed:
        print("Failed")
      }
    }
    
    notificationManager.addObserverTiedToLifetimeOfClass(self) { (note: AppNameNotifications.Posts) in
      if case .updated(let numberOfItems) = note {
        print("Updated \(numberOfItems) posts")
      }
    }
    
    notificationManager.addObserverTiedToLifetimeOfClass(self) { (note: AppNameNotifications.UIKeyboard.WillShow) in
      if let size = note.keyboardSize {
        print("Keyboard will show with size: \(size)")
      }
    }
  }
}

//An example of how to tie nofications to a class and avoid the automatic handling in map tables.
class AnotherVC: UIViewController {
  
  var tokens: [Token] = []
  var notificationManager: NotificationManager!
  
  func addObservers() {
    
    let token = notificationManager.addObserver{ (note: AppNameNotifications.UIApplication.DidBecomeActive) in
      print("DidBecomeActive")
    }
    tokens.append(token)
  }
}

// Positing notifications

let vc = SomeVC()
// Passing in a notification center allows us to mock easily when testing
let manager = NotificationManager(center: NotificationCenter.default)
vc.notificationManager = manager
vc.addObservers()


manager.post(AppNameNotifications.MediaDownload.success)
manager.post(AppNameNotifications.MediaDownload.failed)
manager.post(AppNameNotifications.Posts.updated(numberOfItems: 7))

//Note, we haven't implemented sending behaviour for system notifications but it may be necessary for testing.

