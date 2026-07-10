import CoreAudio
import EdithKit
import Foundation
import IOBluetooth
import IOKit.ps

@MainActor
final class NotchAlertDetectors {
    private let post: (NotchAlert) -> Void
    private var audioListener: AudioObjectPropertyListenerBlock?
    private var powerSource: CFRunLoopSource?
    private var bluetoothWatcher: BluetoothWatcher?
    private var lastOutputDevice: AudioDeviceID = 0
    private var lastOnAC: Bool?
    private var lastCapacity: Int?
    private var warmingUp = true

    init(post: @escaping (NotchAlert) -> Void) {
        self.post = post
    }

    private func enabled(_ key: String) -> Bool {
        SharedDefaults.store.object(forKey: key) as? Bool ?? true
    }

    func start() {
        lastOutputDevice = Self.defaultOutputDevice()
        let snapshot = Self.readPower()
        lastOnAC = snapshot.onAC
        lastCapacity = snapshot.capacity
        startAudio()
        startPower()
        startBluetooth()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.warmingUp = false
        }
    }

    func stop() {
        if let audioListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, audioListener
            )
        }
        audioListener = nil
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode)
        }
        powerSource = nil
        bluetoothWatcher?.stop()
        bluetoothWatcher = nil
    }

    private func startBluetooth() {
        guard enabled("notchAlertBluetooth") else { return }
        let watcher = BluetoothWatcher { [weak self] name, connected in
            guard let self, !self.warmingUp else { return }
            self.post(
                NotchAlert(
                    id: "bluetooth.\(connected ? "connected" : "disconnected")",
                    icon: connected ? "wave.3.right.circle.fill" : "wave.3.right.circle",
                    tint: connected ? "#4db3e6" : "#8a7d6c",
                    title: name, subtitle: connected ? "Connected" : "Disconnected",
                    priority: .low, autoHide: 2.5))
        }
        watcher.start()
        bluetoothWatcher = watcher
    }

    private func startAudio() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.audioChanged() }
        }
        audioListener = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block)
    }

    private func audioChanged() {
        let device = Self.defaultOutputDevice()
        guard device != lastOutputDevice, device != 0 else { return }
        lastOutputDevice = device
        guard !warmingUp, enabled("notchAlertAudio") else { return }
        post(
            NotchAlert(
                id: "audio.output", icon: "hifispeaker.fill", tint: "#4db3e6",
                title: Self.deviceName(device), subtitle: "Audio output", priority: .low,
                autoHide: 2.5))
    }

    private func startPower() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard
            let source = IOPSNotificationCreateRunLoopSource(
                { context in
                    guard let context else { return }
                    let detectors = Unmanaged<NotchAlertDetectors>.fromOpaque(context)
                        .takeUnretainedValue()
                    Task { @MainActor in detectors.powerChanged() }
                }, context)?.takeRetainedValue()
        else { return }
        powerSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func powerChanged() {
        let now = Self.readPower()
        defer {
            lastOnAC = now.onAC
            lastCapacity = now.capacity
        }
        guard !warmingUp else { return }
        if let onAC = now.onAC, onAC != lastOnAC, enabled("notchAlertPower") {
            let subtitle = now.capacity.map { "\($0)%" }
            if onAC {
                post(
                    NotchAlert(
                        id: "power.charging", icon: "bolt.fill", tint: "#4cc47e",
                        title: now.charging == true ? "Charging" : "Plugged in",
                        subtitle: subtitle, priority: .low, autoHide: 2.5))
            } else {
                post(
                    NotchAlert(
                        id: "power.charging", icon: "bolt.slash.fill", tint: "#e0a83f",
                        title: "On battery", subtitle: subtitle, priority: .low, autoHide: 2.5))
            }
        }
        if let capacity = now.capacity, let last = lastCapacity, capacity <= 20, last > 20,
            enabled("notchAlertBattery")
        {
            post(
                NotchAlert(
                    id: "battery.low", icon: "battery.25", tint: "#e0664f", title: "Battery low",
                    subtitle: "\(capacity)%", priority: .high, autoHide: 4))
        }
    }

    private static func defaultOutputDevice() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }

    private static func deviceName(_ device: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name)
        guard status == noErr, let value = name?.takeRetainedValue() else { return "Output device" }
        return value as String
    }

    private static func readPower() -> (onAC: Bool?, charging: Bool?, capacity: Int?) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return (nil, nil, nil) }
        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any]
            else { continue }
            let state = description[kIOPSPowerSourceStateKey] as? String
            let onAC = state.map { $0 == kIOPSACPowerValue }
            let charging = description[kIOPSIsChargingKey] as? Bool
            let capacity = description[kIOPSCurrentCapacityKey] as? Int
            return (onAC, charging, capacity)
        }
        return (nil, nil, nil)
    }
}

final class BluetoothWatcher: NSObject {
    private let changed: @MainActor (String, Bool) -> Void
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]

    init(changed: @escaping @MainActor (String, Bool) -> Void) {
        self.changed = changed
    }

    func start() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        for device in IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        where device.isConnected() {
            watchDisconnect(device)
        }
    }

    func stop() {
        connectNotification?.unregister()
        connectNotification = nil
        for notification in disconnectNotifications.values { notification.unregister() }
        disconnectNotifications.removeAll()
    }

    private func watchDisconnect(_ device: IOBluetoothDevice) {
        guard let key = device.addressString, disconnectNotifications[key] == nil else { return }
        disconnectNotifications[key] = device.register(
            forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
    }

    @objc private func deviceConnected(
        _ notification: IOBluetoothUserNotification, device: IOBluetoothDevice
    ) {
        let name = device.name ?? "Bluetooth device"
        watchDisconnect(device)
        Task { @MainActor in self.changed(name, true) }
    }

    @objc private func deviceDisconnected(
        _ notification: IOBluetoothUserNotification, device: IOBluetoothDevice
    ) {
        let name = device.name ?? "Bluetooth device"
        if let key = device.addressString, let note = disconnectNotifications.removeValue(forKey: key) {
            note.unregister()
        }
        Task { @MainActor in self.changed(name, false) }
    }
}
