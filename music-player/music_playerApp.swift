//
//  music_playerApp.swift
//  music-player
//
//  Created by Satrio Indrajit Arroisi on 03/02/26.
//

import SwiftUI
import AppKit

@main
struct music_playerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var musicService = iTunesService.shared

    var body: some Scene {
        WindowGroup {
            MusicPlayerView()
                .environmentObject(audioPlayer)
                .environmentObject(musicService)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .defaultSize(width: 1400, height: 900)
    }
}

// MARK: - App Delegate to configure window
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure window multiple times to ensure it sticks
        for delay in [0.1, 0.3, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if let window = NSApplication.shared.windows.first {
                    self.configureWindow(window)
                }
            }
        }

        // Also observe for new windows
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            configureWindow(window)
        }
    }

    private func configureWindow(_ window: NSWindow) {
        let yellowColor = NSColor(red: 1, green: 0.949, blue: 0, alpha: 1)

        // Basic window setup
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = ""
        window.isMovableByWindowBackground = true
        window.backgroundColor = yellowColor

        // Full size content view
        window.styleMask.insert(.fullSizeContentView)

        // Remove toolbar separator
        window.titlebarSeparatorStyle = .none

        // Remove any toolbar
        window.toolbar = nil

        // Make the entire titlebar area transparent
        if let themeFrame = window.contentView?.superview {
            // Find and configure the titlebar view
            for subview in themeFrame.subviews {
                let className = String(describing: type(of: subview))
                if className.contains("Titlebar") || className.contains("toolbar") {
                    subview.wantsLayer = true
                    subview.layer?.backgroundColor = NSColor.clear.cgColor

                    // Also clear all nested subviews
                    clearBackgrounds(in: subview)
                }
            }
        }
    }

    private func clearBackgrounds(in view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        for subview in view.subviews {
            // Don't clear the traffic light buttons themselves
            if !(subview is NSButton) {
                clearBackgrounds(in: subview)
            }
        }
    }
}
