import SwiftUI

/// Alias de `SwiftUI.State`.
///
/// Depuis le SDK macOS 27, `@State` est une macro dont le plugin n'est livré qu'avec
/// Xcode. Avec les seules Command Line Tools, on passe donc par cet alias, qui utilise
/// directement le property wrapper `State` (comportement identique).
/// Si Xcode est installé, on peut remplacer `@ViewState` par `@State` partout.
typealias ViewState = SwiftUI.State
