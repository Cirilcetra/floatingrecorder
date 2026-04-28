import Foundation

extension Notification.Name {
    static let showFloating = Notification.Name("FloatingRecorder.ShowFloating")
    static let hideFloating = Notification.Name("FloatingRecorder.HideFloating")
    static let closeFloating = Notification.Name("FloatingRecorder.CloseFloating")
    static let showPreferences = Notification.Name("FloatingRecorder.ShowPreferences")
    static let startPushToTalk = Notification.Name("FloatingRecorder.StartPushToTalk")
    static let stopPushToTalk = Notification.Name("FloatingRecorder.StopPushToTalk")
    static let toggleRecording = Notification.Name("FloatingRecorder.ToggleRecording")
}
