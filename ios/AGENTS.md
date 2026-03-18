# SwiftAgents Rules

All Swift/SwiftUI code in this project follows these rules:

## Platform & Language
- iOS 26+, Swift 6.2+
- Strict Swift concurrency enabled

## SwiftUI Patterns
- `@Observable` classes marked `@MainActor` for all shared data
- `@State` for ownership, `@Environment` for passing
- No `ObservableObject`, `@Published`, `@StateObject`, or `@EnvironmentObject`
- `foregroundStyle()` not `foregroundColor()`
- `clipShape(.rect(cornerRadius:))` not `cornerRadius()`
- No `GeometryReader` — use `containerRelativeFrame()` instead
- `Button` not `onTapGesture` for all tap interactions (except video player)
- `.scrollIndicators(.hidden)` not `showsIndicators`
- `NavigationStack` + `navigationDestination(for:)` for navigation
- Break views into separate `View` structs, not computed properties

## Concurrency
- No GCD — use `Task`, `async/await`, `AsyncStream` everywhere
- No force unwraps, no `try!`

## Layout & Accessibility
- No `UIScreen.main.bounds` — use SwiftUI layout
- Dynamic Type, no hard-coded font sizes
- No UIKit unless unavoidable (AVPlayerLayer via UIViewRepresentable is allowed)
