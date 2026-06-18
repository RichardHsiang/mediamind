import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                     .background(
                         LinearGradient(
                             colors: [.appleBlue, .applePurple],
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing
                         )
                     )
                    .cornerRadius(10)

                Text("MediaMind")
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)

            // Navigation
            VStack(spacing: 4) {
                SidebarItem(
                    icon: "house.fill",
                    title: "主页",
                    isSelected: selectedTab == .home,
                    isDisabled: false
                ) {
                    selectedTab = .home
                }

                SidebarItem(
                    icon: "photo.on.rectangle",
                    title: "视频截图",
                    isSelected: selectedTab == .screenshot,
                    isDisabled: false
                ) {
                    selectedTab = .screenshot
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Settings
            VStack(spacing: 4) {
                SidebarItem(
                    icon: "gearshape",
                    title: "设置",
                    isSelected: selectedTab == .settings,
                    isDisabled: false
                ) {
                    selectedTab = .settings
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
         .frame(width: 200)
         .background(Color.appleCard)
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))

                Spacer()
            }
            .foregroundColor(isSelected ? .white : (isDisabled ? .secondary : .primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.appleBlue : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

enum SidebarTab {
    case home
    case screenshot
    case settings
}