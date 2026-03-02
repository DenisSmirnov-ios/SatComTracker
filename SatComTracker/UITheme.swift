import SwiftUI

enum UITheme {
    static func backgroundTop(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.10, green: 0.12, blue: 0.16)
            : Color(red: 0.94, green: 0.97, blue: 1.00)
    }

    static func backgroundBottom(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.04, green: 0.05, blue: 0.08)
            : Color(red: 0.99, green: 0.99, blue: 1.00)
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.15, green: 0.17, blue: 0.22).opacity(0.92)
            : Color.white.opacity(0.90)
    }

    static func surfaceBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.18, green: 0.20, blue: 0.25).opacity(0.92)
            : Color.white.opacity(0.92)
    }

    static func cardBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    static func shadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.26) : Color.black.opacity(0.08)
    }

    static let accent = Color(red: 0.10, green: 0.38, blue: 0.76)
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [UITheme.backgroundTop(for: colorScheme), UITheme.backgroundBottom(for: colorScheme)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct AppCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 16
    var borderOpacity: Double = 1

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(UITheme.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(UITheme.cardBorder(for: colorScheme).opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: UITheme.shadow(for: colorScheme), radius: 10, y: 4)
    }
}

struct AppToolbarIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(UITheme.accent)
            .frame(width: 32, height: 32)
            .background(UITheme.surfaceBackground(for: colorScheme).opacity(configuration.isPressed ? 0.70 : 0.98))
            .clipShape(Circle())
            .overlay(Circle().stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1))
            .shadow(color: UITheme.shadow(for: colorScheme), radius: 6, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func appCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius))
    }
}
