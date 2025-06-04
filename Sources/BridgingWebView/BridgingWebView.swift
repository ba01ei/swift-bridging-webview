//
//  WebView.swift
//
//  Created by Bao Lei on 5/24/25.
//


import SwiftUI
import UIKit
import WebKit

/// Create a WebView that supports bidirectional respondable bridging activities.
/// To send a message from native to web, call `await webCaller.sendMessageToWeb(json)`.
/// On the web side, handle that by setting `window["WebNaitveBridge"].nativeToWeb = { ... }`
/// To send a message from web to native, call `await window["WebNaitveBridge"].webToNative(json)`
/// On the native side, handle that in `onWebRequest`
/// The bridge name (`WebNaitveBridge`) and function names (`webToNative` & `nativeToWeb`) can be customized.
/// Example:
/// ```
///struct ContentView: View {
///  let webCaller = WebCaller()
///  var body: some View {
///    WebView(url: WebURL, webCaller: webCaller) { webRequest in
///      guard let webRequest = webRequest as? [String: Any] else { return }
///      switch webRequest["type"] {
///      case "type1":
///        ...
///      default:
///        print("unrecognized request")
///        return [:]
///    }
///  }
///
///  // call webCaller.sendRequestToWeb(...) to request something from web
/// ```
public struct BridgingWebView: UIViewRepresentable {
  private let url: URL?
  private let bridgeName: String
  private let webToNativeFunctionName: String
  private let nativeToWebFunctionName: String
  private var onWebRequest: (Any) async throws -> [String: Any]?
  private var webCaller: WebCaller?

  public init(
    url: URL?,
    bridgeName: String = "WebNativeBridge",
    webToNativeFunctionName: String = "webToNative",
    nativeToWebFunctionName: String = "nativeToWeb",
    webCaller: WebCaller?,
    onWebRequest: @escaping ((_ webRequest: any Sendable) async throws -> [String: any Sendable]?)) {
      self.url = url
      self.bridgeName = bridgeName
      self.webToNativeFunctionName = webToNativeFunctionName
      self.nativeToWebFunctionName = nativeToWebFunctionName
      self.onWebRequest = onWebRequest
      self.webCaller = webCaller
  }
  
  // Reference to the coordinator for calling JavaScript from native
  @State private var coordinator: Coordinator?

  public func makeUIView(context: Context) -> WKWebView {
    let coordinator = context.coordinator
    Task {
      self.coordinator = coordinator
    }
    webCaller?.sendMessageToWeb = sendMessageToWeb
    webCaller?.reloadUrl = reloadUrl
    webCaller?.currentUrl = currentUrl
    
    let configuration = WKWebViewConfiguration()
    
    // Add user content controller for JavaScript communication
    let userContentController = WKUserContentController()
    userContentController.addUserScript(WKUserScript(source: JavaScriptBridge.setupScript(bridgeName: bridgeName, webToNativeFunctionName: webToNativeFunctionName), injectionTime: .atDocumentStart, forMainFrameOnly: true))
    configuration.userContentController = userContentController
    userContentController.addScriptMessageHandler(coordinator, contentWorld: .page, name: bridgeName)
    
    let webView = WKWebView(frame: .zero, configuration: configuration)
    coordinator.webView = webView
    #if DEBUG
    if #available(iOS 16.4, macCatalyst 16.4, *) {
      webView.isInspectable = true
    }
    #endif

    // Load content
    if let url {
      let request = URLRequest(url: url)
      webView.load(request)
    }
    return webView
  }
  
  public func updateUIView(_ uiView: WKWebView, context: Context) {
  }
  
  public func makeCoordinator() -> Coordinator {
    Coordinator(onWebRequest: onWebRequest)
  }
  
  @MainActor private func sendMessageToWeb(parameters: [String: any Sendable]) async throws -> Any? {
    return try await coordinator?.sendMessageToWeb(js: "return await window.\(bridgeName).\(nativeToWebFunctionName)(data)", parameters: ["data": parameters])
  }
  
  @MainActor private func reloadUrl(_ url: URL?) -> Void {
    if let url {
      coordinator?.webView?.load(URLRequest(url: url))
    }
  }
  
  @MainActor private func currentUrl() -> URL? {
    return coordinator?.webView?.url
  }
}

@MainActor public final class WebCaller {
  public fileprivate(set) var sendMessageToWeb: (@MainActor (_ parameters: [String: any Sendable]) async throws -> (any Sendable)?)? = nil
  public fileprivate(set) var reloadUrl: (@MainActor (_ url: URL?) -> Void)? = nil
  public fileprivate(set) var currentUrl: (@MainActor () -> URL?)? = nil
  
  public init() {}
}

// MARK: - Coordinator
extension BridgingWebView {
  public class Coordinator: NSObject, WKScriptMessageHandlerWithReply {
    private var onWebRequest: (_ webRequest: Any) async throws -> [String: any Sendable]?
    weak var webView: WKWebView?
    
    init(onWebRequest: @escaping (Any) async throws -> [String: any Sendable]?) {
      self.onWebRequest = onWebRequest
    }
    
    // Handle calls from JavaScript
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping @MainActor (Any?, String?) -> Void) {
      Task {
        do {
          let result = try await onWebRequest(message.body)
          replyHandler(result, nil)
        } catch {
          replyHandler(nil, "\(error)")
        }
      }
    }

    // Call JavaScript from native
    func sendMessageToWeb(js: String, parameters: [String: any Sendable]) async throws -> Any? {
      return try await webView?.callAsyncJavaScript(js, arguments: parameters, in: nil, contentWorld: .page)
    }
  }
}

// MARK: - JavaScript Bridge Helper
struct JavaScriptBridge {
  static func setupScript(bridgeName: String, webToNativeFunctionName: String) -> String {
    return """
      window.\(bridgeName) = {
        \(webToNativeFunctionName): async function (data) {
          return window.webkit.messageHandlers.\(bridgeName).postMessage(data);
        },
      };
    """
  }
}


