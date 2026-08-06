import Foundation

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
}
