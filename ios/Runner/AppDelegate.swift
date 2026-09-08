import Flutter
import UIKit
import AVFoundation
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var remoteFeedbackChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register custom iOS plugins
    if let controller = window?.rootViewController as? FlutterViewController {
      configureRemoteFeedback(with: controller)

      // iOS System Integration Plugin
      let systemPluginRegistrar = registrar(forPlugin: "iOSSystemPlugin")
      if systemPluginRegistrar != nil {
        iOSSystemPlugin.register(with: systemPluginRegistrar!)
      }
      
      // iOS Bluetooth/CarPlay Plugin
      let bluetoothPluginRegistrar = registrar(forPlugin: "iOSBluetoothPlugin")
      if bluetoothPluginRegistrar != nil {
        iOSBluetoothPlugin.register(with: bluetoothPluginRegistrar!)
      }

      // AirPlay button platform view
      let airPlayRegistrar = registrar(forPlugin: "AirPlayButtonFactory")
      if airPlayRegistrar != nil {
        registerAirPlayButtonFactory(with: airPlayRegistrar!)
      }

    }
    
    // Configure audio session for background playback
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [])
      try audioSession.setActive(true)
      print("Audio session configured for background playback")
    } catch {
      print("Failed to configure audio session: \(error)")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Registers iOS's system feedback command. The OS decides where to expose
  /// it (expanded Lock Screen/Control Center versus compact controls), but
  /// when invoked it toggles Musly's own liked-song state in Flutter.
  private func configureRemoteFeedback(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.devid.musly/remote_feedback",
      binaryMessenger: controller.binaryMessenger
    )
    remoteFeedbackChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "setLikeState",
            let arguments = call.arguments as? [String: Any],
            let active = arguments["active"] as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      let commandCenter = MPRemoteCommandCenter.shared()
      let bookmarkCommand = commandCenter.bookmarkCommand
      let likeCommand = commandCenter.likeCommand
      // audio_service disables feedback commands while initializing the shared
      // command center. Re-enable this supported command whenever Dart sends
      // current-track state, which happens after that setup.
      bookmarkCommand.isEnabled = true
      bookmarkCommand.isActive = active
      likeCommand.isEnabled = true
      likeCommand.isActive = active
      result(nil)
    }

    let commandCenter = MPRemoteCommandCenter.shared()
    // iOS chooses which feedback command to expose for the single favorite
    // slot, depending on the Lock Screen presentation and OS version. Both
    // map to Musly's one liked-song action.
    let bookmarkCommand = commandCenter.bookmarkCommand
    bookmarkCommand.isEnabled = true
    bookmarkCommand.localizedTitle = "Favorite"
    bookmarkCommand.addTarget { [weak self] _ in
      let active = !commandCenter.bookmarkCommand.isActive
      commandCenter.bookmarkCommand.isActive = active
      commandCenter.likeCommand.isActive = active
      self?.remoteFeedbackChannel?.invokeMethod(
        "toggleLike",
        arguments: ["active": active]
      )
      return .success
    }
    let likeCommand = commandCenter.likeCommand
    likeCommand.isEnabled = true
    likeCommand.localizedTitle = "Favorite"
    likeCommand.addTarget { [weak self] _ in
      let active = !commandCenter.likeCommand.isActive
      commandCenter.bookmarkCommand.isActive = active
      commandCenter.likeCommand.isActive = active
      self?.remoteFeedbackChannel?.invokeMethod(
        "toggleLike",
        arguments: ["active": active]
      )
      return .success
    }
  }
  
  override func applicationWillResignActive(_ application: UIApplication) {
    // Keep audio session active when app goes to background
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Maintain audio playback in background
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    // Clean up audio session
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
  }
}
