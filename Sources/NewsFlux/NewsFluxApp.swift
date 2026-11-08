import AppKit
import SwiftUI
import UserNotifications

@main
struct NewsFluxApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @ViewState private var store = FeedStore()
    @AppStorage(AppDelegate.showMenuBarKey) private var showMenuBar = true

    var body: some Scene {
        Window("NewsFlux", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Actualiser") { Task { await store.refresh() } }
                    .keyboardShortcut("r")
            }
        }

        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarView()
                .environment(store)
        } label: {
            // Icône + nombre de non lus.
            let unread = store.totalUnread
            Image(systemName: unread > 0 ? "newspaper.fill" : "newspaper")
            if unread > 0 { Text("\(unread)") }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @AppStorage(AppDelegate.showMenuBarKey) private var showMenuBar = true

    var body: some View {
        Form {
            Toggle("Afficher NewsFlux dans la barre des menus", isOn: $showMenuBar)
            Text("Quand l'icône est affichée, NewsFlux continue de vérifier les flux après la fermeture de la fenêtre.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Notifications : clic droit sur un flux → « Activer les notifications ».")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static let showMenuBarKey = "showMenuBarExtra"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nécessaire quand l'app est lancée via `swift run` (sans bundle .app).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if Notifier.isAvailable { UNUserNotificationCenter.current().delegate = self }
    }

    /// Avec l'icône dans la barre des menus, l'app reste active une fois la fenêtre fermée.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !(UserDefaults.standard.object(forKey: Self.showMenuBarKey) as? Bool ?? true)
    }

    // Afficher les notifications même quand l'app est au premier plan.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Un clic sur la notification ouvre l'article dans le navigateur.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let link = response.notification.request.content.userInfo["link"] as? String,
           let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        completionHandler()
    }
}
