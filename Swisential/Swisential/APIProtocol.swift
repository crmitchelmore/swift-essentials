import Foundation
public enum Result<T> {
  case success(T)
  case error(Error)
}
public protocol APIProtocol {
  var baseUrl: URL { get }
  var headerFields: [String: String] { get }
  func load<A>(resource: Resource<A>, completion: @escaping (Result<A>) -> Void)
}

public enum HttpMethod<Body> {
  case get
  case delete
  case head
  case post(Body)
  case put(Body)
  case postFormUrlEncoded(Body)
  case putFormUrlEncoded(Body)
}

public struct Resource<A> {
  let method: HttpMethod<Data>
  let path: String
  let headerFields: [String: String]
  let parameters: [String: String]
  let cachePolicy: URLRequest.CachePolicy?
  let parse: (Data) throws -> A
}

public final class API: APIProtocol {
  
  let session: URLSession
  public let baseUrl: URL
  public let headerFields: [String: String]
  
  public init(baseUrl: String, headerFields: [String: String] = [:]) {
    self.session = URLSession(configuration: URLSessionConfiguration.default)
    self.headerFields = headerFields
    
    var baseURLWithoutTrailingSlash = baseUrl
    if "\(baseUrl.characters.last)" == "/" {
      baseURLWithoutTrailingSlash = String(baseURLWithoutTrailingSlash.characters.dropLast())
    }
    self.baseUrl = URL(string: baseURLWithoutTrailingSlash)!
  }
  
  public convenience init(baseUrl: String, apiKey: String) {
    self.init(baseUrl: baseUrl, headerFields: ["Authorization": apiKey])
  }
  
  public func load<A>(resource: Resource<A>, completion: @escaping (Result<A>) -> Void) {
    let request = URLRequest(api: self, resource: resource)
    session.dataTask(with: request) { data, _, error in
      if let error = error {
        completion(.error(error))
      } else if let data = data {
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let result = try resource.parse(data)
            DispatchQueue.main.async { completion(.success(result)) }
          } catch let e {
            DispatchQueue.main.async { completion(.error(e)) }
          }
        }
      }
      }.resume()
  }
}

extension URLRequest {
  
  public init<A>(api: APIProtocol, resource: Resource<A>) {
    let resourceUrl = URL(string: resource.path) //If resource has a base url use that
    
    var url: URL! = nil
    if resourceUrl?.host != nil {
      url = resourceUrl
    } else {
      let addCharacter = resource.path.characters.first == "/" ? "" : "/"
      let resourcePath = addCharacter + resource.path
      url = URL(string: api.baseUrl.absoluteString + resourcePath)
    }
    
    if resource.parameters.count > 0 {
      
      var parameters: [String: String] = [:]
      url.query?.components(separatedBy: "&").forEach {
        let params = $0.components(separatedBy: "=")
        if params.count == 2 {
          parameters[params[0]] = params[1]
        }
      }
      resource.parameters.forEach { parameters[$0] = $1 }
      let paramString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
      url = URL(string: "\(url.absoluteString.components(separatedBy: "?")[0])?\(paramString)")!
    }
    
    self.init(url: url)
    switch resource.method {
    case .put, .post:
      self.addValue("application/json", forHTTPHeaderField: "Content-Type")
    default: break
    }
    
    if let cachePolicy = resource.cachePolicy {
      self.cachePolicy = cachePolicy
    }
    
    api.headerFields.forEach { self.addValue($1, forHTTPHeaderField: $0) }
    resource.headerFields.forEach {  self.addValue($1, forHTTPHeaderField: $0) }
    httpMethod = resource.method.name
    if let data = resource.httpBody {
      httpBody = data
    }
  }
}

extension HttpMethod {
  public var name: String {
    switch self {
    case .get: return "GET"
    case .delete: return "DELETE"
    case .post, .postFormUrlEncoded: return "POST"
    case .put, .putFormUrlEncoded: return "PUT"
    case .head: return "HEAD"
    }
  }
  
  public func map<B>(f: (Body) -> B) -> HttpMethod<B> {
    switch self {
    case .get: return .get
    case .delete: return .delete
    case .head: return .head
    case .post(let body): return .post(f(body))
    case .postFormUrlEncoded(let body): return .post(f(body))
    case .put(let body): return .put(f(body))
    case .putFormUrlEncoded(let body): return .post(f(body))
    }
  }
}

extension Resource {
  
  public init(method: HttpMethod<AnyObject> = .get, path: String, headerFields: [String: String] = [:], parameters: [String: String] = [:], cachePolicy: URLRequest.CachePolicy? = nil, parseJson: @escaping (Any) throws -> A) {
    self.method = method.map { json in try! JSONSerialization.data(withJSONObject: json, options: []) }
    self.path = path
    self.headerFields = headerFields
    self.parameters = parameters
    self.cachePolicy = cachePolicy
    self.parse = { data in
      let json = try JSONSerialization.jsonObject(with: data, options: [])
      return try parseJson(json)
    }
  }
  
  public var httpBody: Data? {
    switch method {
    case .get, .delete, .head: return nil
    case .post(let content): return content
    case .postFormUrlEncoded(let content): return content
    case .put(let content): return content
    case .putFormUrlEncoded(let content): return content
    }
  }
}

