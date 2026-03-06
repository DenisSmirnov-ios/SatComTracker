import SwiftUI

enum UITheme {
    static func backgroundTop(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.05, green: 0.08, blue: 0.18)
            : Color(red: 0.86, green: 0.93, blue: 0.99)
    }

    static func backgroundBottom(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.08, green: 0.19, blue: 0.33)
            : Color(red: 0.74, green: 0.85, blue: 0.97)
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.11, green: 0.15, blue: 0.22).opacity(0.92)
            : Color.white.opacity(0.90)
    }

    static func surfaceBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.13, green: 0.18, blue: 0.26).opacity(0.92)
            : Color.white.opacity(0.92)
    }

    static func cardBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    static func shadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.26) : Color.black.opacity(0.08)
    }

    static let accent = Color(red: 0.15, green: 0.55, blue: 0.92)
    static let accentInverted = Color(red: 0.85, green: 0.45, blue: 0.08)
    static let radar = Color(red: 0.34, green: 0.74, blue: 1.0)

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? accentInverted : accent
    }
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
            .foregroundColor(UITheme.accent(for: colorScheme))
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
