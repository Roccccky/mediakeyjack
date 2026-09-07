// Routes the media keys to Spotify by taking their events off the queue.
//
// A CGEventTap at the head of the event chain consumes the aux button events,
// so neither Music.app nor com.apple.rcd ever receives them.

import Cocoa
import ApplicationServices

let spotifyBundleID = "com.spotify.client"

/// Launch Spotify automatically when play/pause is pressed and it isn't running.
let launchSpotifyOnPlay = true

// Aux key codes of the media keys (IOKit / NX_KEYTYPE_*)
let keyPlay     = 16
let keyNext     = 17
let keyPrevious = 18
let keyFast     = 19   // sent by the ⏭ key on many keyboards
let keyRewind   = 20   // sent by the ⏮ key on many keyboards

var eventTap: CFMachPort?

// MARK: - Controlling Spotify

enum Command: String {
    case playPause = "playpause"
    case next      = "next track"
    case previous  = "previous track"
}

/// Serial queue: AppleScript must never block the event tap thread, otherwise
/// macOS disables the tap for timing out.
let scriptQueue = DispatchQueue(label: "io.github.roccccky.mediakeyjack.script")
var scriptCache: [String: NSAppleScript] = [:]   // only touch this on scriptQueue

func spotifyIsRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: spotifyBundleID).isEmpty
}

func ensureSpotifyRunning(startIfNeeded: Bool) -> Bool {
    if spotifyIsRunning() { return true }
    guard startIfNeeded, launchSpotifyOnPlay,
          let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: spotifyBundleID)
    else { return false }

    let config = NSWorkspace.OpenConfiguration()
    config.activates = false           // don't steal focus
    NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)

    // Wait for Spotify to come up and become scriptable (~10s max).
    for _ in 0..<40 {
        if spotifyIsRunning() {
            Thread.sleep(forTimeInterval: 1.5)   // head start before scripting it
            return true
        }
        Thread.sleep(forTimeInterval: 0.25)
    }
    return false
}

func send(_ command: Command) {
    scriptQueue.async {
        guard ensureSpotifyRunning(startIfNeeded: command == .playPause) else { return }

        let source = "tell application id \"\(spotifyBundleID)\" to \(command.rawValue)"
        let script: NSAppleScript
        if let cached = scriptCache[source] {
            script = cached
        } else {
            guard let fresh = NSAppleScript(source: source) else { return }
            scriptCache[source] = fresh
            script = fresh
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            FileHandle.standardError.write("MediaKeyJack: AppleScript error: \(error)\n".data(using: .utf8)!)
        }
    }
}

// MARK: - Event tap

func eventCallback(proxy: CGEventTapProxy,
                   type: CGEventType,
                   event: CGEvent,
                   refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    // macOS disables the tap if a callback takes too long - just switch it back on.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    // We only care about NX_SYSDEFINED (14) with subtype 8 (aux control buttons).
    guard type.rawValue == 14,
          let nsEvent = NSEvent(cgEvent: event),
          nsEvent.subtype.rawValue == 8
    else { return Unmanaged.passUnretained(event) }

    let data1     = nsEvent.data1
    let keyCode   = Int((data1 & 0xFFFF_0000) >> 16)
    let keyFlags  = data1 & 0x0000_FFFF
    let isKeyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A
    let isRepeat  = (keyFlags & 0x1) == 1

    switch keyCode {
    case keyPlay, keyNext, keyPrevious, keyFast, keyRewind:
        if isKeyDown && !isRepeat {
            switch keyCode {
            case keyPlay:            send(.playPause)
            case keyNext, keyFast:   send(.next)
            default:                 send(.previous)
            }
        }
        return nil   // consumed, Music.app never sees the key

    default:
        return Unmanaged.passUnretained(event)
    }
}

// MARK: - Startup

_ = NSApplication.shared           // initialise AppKit (needed for NSEvent(cgEvent:))
NSApplication.shared.setActivationPolicy(.accessory)

let mask = CGEventMask(1 << 14)    // NX_SYSDEFINED
var prompted = false

while eventTap == nil {
    eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                 place: .headInsertEventTap,
                                 options: .defaultTap,
                                 eventsOfInterest: mask,
                                 callback: eventCallback,
                                 userInfo: nil)
    if eventTap == nil {
        if !prompted {
            prompted = true
            FileHandle.standardError.write(
                "MediaKeyJack: no Accessibility permission - please grant it in System Settings.\n"
                    .data(using: .utf8)!)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        Thread.sleep(forTimeInterval: 2)
    }
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap!, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap!, enable: true)

FileHandle.standardError.write("MediaKeyJack: running - media keys now go to Spotify.\n".data(using: .utf8)!)
CFRunLoopRun()
