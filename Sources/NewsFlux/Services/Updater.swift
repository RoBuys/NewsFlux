import Combine
import Sparkle
import SwiftUI

/// Mises à jour automatiques via Sparkle.
///
/// Le flux de mises à jour (`SUFeedURL`) et la clé publique (`SUPublicEDKey`) sont dans Info.plist.
/// Chaque release GitHub publie `appcast.xml`, généré par `scripts/release.sh`.
@MainActor
final class Updater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published var automaticallyChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    private let controller: SPUStandardUpdaterController?
    private var cancellables: Set<AnyCancellable> = []

    /// Sparkle n'est actif que dans la .app (pas avec `swift run`).
    var isAvailable: Bool { controller != nil }

    init() {
        let bundled = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        controller = bundled
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        automaticallyChecks = controller?.updater.automaticallyChecksForUpdates ?? false

        controller?.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

/// Élément de menu « Rechercher des mises à jour… ».
struct CheckForUpdatesButton: View {
    @ObservedObject var updater: Updater

    var body: some View {
        Button("Rechercher des mises à jour…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
    }
}
