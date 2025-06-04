# BridgingWebView

A SwiftUI webview with bridiging capabilities

## How to use

```swift
struct ContentView: View {
  let webCaller = WebCaller()
  var body: some View {
    VStack {
      WebView(url: WebURL, webCaller: webCaller) { webRequest in
        // handling web -> native request
        guard let webRequest = webRequest as? [String: Any] else { return }
        switch webRequest["type"] {
        case "action1":
          print("received \(webRequest)")
          return ["result": 1]
        default:
          print("unrecognized request")
          return [:]
      }
      Button("Send native -> web request") {
        Task {
          let result = await webCaller.sendRequestToWeb(["type": "actionA", data: [:]])
          print("result from web: \(web)")
        }
      }
    }
  }
```
    
### Setup on the webside

Handling native to web request

```typescript
if (window["WebNativeBridge"]) {
  window["WebNativeBridge"].nativeToWeb = (data: any) => {
    if (data.type === "actionA") {
      console.log("received native request", data)
      return {result: "a"}
    }
  };
}
```

Sending request to native

```typescript
async function sendBridgeMessage(message: { type: string; data: any }): Promise<any> {
  return await window["WebNativeBridge"]?.webToNative?.(message);
}

```

### Customization

| Parameters of BridigingWebView | Default value |
| --- | --- |
| bridgeName | WebNativeBridge |
| webToNativeFunctionName | webToNative |
| nativeToWebFunctionName | nativeToWeb |
