import Cocoa
import FlutterMacOS
import HotKey
import Carbon

public class HotkeyManagerMacosPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var _eventSink: FlutterEventSink?
    
    var hotKeyDict: Dictionary<String, HotKey> = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dev.leanflutter.plugins/hotkey_manager", binaryMessenger: registrar.messenger)
        let instance = HotkeyManagerMacosPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        let eventChannel = FlutterEventChannel(name: "dev.leanflutter.plugins/hotkey_manager_event", binaryMessenger: registrar.messenger)
        eventChannel.setStreamHandler(instance)
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self._eventSink = events
        return nil;
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self._eventSink = nil
        return nil
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "register":
            register(call, result: result)
            break
        case "unregister":
            unregister(call, result: result)
            break
        case "unregisterAll":
            unregisterAll(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func register(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        
        let keyCode = args["keyCode"] as! UInt32
        let modifiers = args["modifiers"] as! Array<String>
        let identifier = args["identifier"] as! String
        
        let hotKey: HotKey = HotKey(
            key: Key(carbonKeyCode: keyCode)!,
            modifiers: NSEvent.ModifierFlags.init(pluginModifiers: modifiers)
        )
        hotKey.keyDownHandler = {
            guard let eventSink = self._eventSink else {
                return
            }
            let event: NSDictionary = [
                "type": "onKeyDown",
                "data": call.arguments as! NSDictionary,
            ]
            eventSink(event)
        }
        hotKey.keyUpHandler = {
            guard let eventSink = self._eventSink else {
                return
            }
            let event: NSDictionary = [
                "type": "onKeyUp",
                "data": call.arguments as! NSDictionary,
            ]
            eventSink(event)
        }
        self.hotKeyDict[identifier] = hotKey
        result(true)
    }
    
    public func unregister(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        
        let identifier = args["identifier"] as! String
        
        self.hotKeyDict[identifier] = nil;
        
        result(true)
    }
    
    public func unregisterAll(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.hotKeyDict.removeAll();
        result(true)
    }
}
