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

    private var contentView: some View {
        ZStack {
            // 所有页面都保持活跃，避免重复创建和销毁
            HomeView()
                .opacity(selectedTab == .home ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(selectedTab == .home)

            ScreenshotView()
                .opacity(selectedTab == .screenshot ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(selectedTab == .screenshot)

            SettingsView()
                .opacity(selectedTab == .settings ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(selectedTab == .settings)
        }
    }
}