import SwiftUI

struct MainView: View {
    @State private var selectedTab: SidebarTab = .home

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTab: $selectedTab)

            Divider()

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appleBackground)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .home:
            HomeView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}
