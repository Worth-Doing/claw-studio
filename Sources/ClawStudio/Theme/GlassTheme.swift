import SwiftUI

// MARK: - Legendary Light Glass UI Design System

enum GlassTheme {
    // MARK: - Accent Palette (vivid, premium)
    static let accentPrimary = Color(red: 0.22, green: 0.45, blue: 1.0)      // Electric blue
    static let accentSecondary = Color(red: 0.52, green: 0.32, blue: 0.98)    // Rich violet
    static let accentTertiary = Color(red: 0.0, green: 0.78, blue: 0.72)      // Teal mint
    static let accentWarning = Color(red: 0.96, green: 0.65, blue: 0.14)      // Warm amber
    static let accentError = Color(red: 0.95, green: 0.28, blue: 0.28)        // Vivid red
    static let accentSuccess = Color(red: 0.15, green: 0.78, blue: 0.42)      // Emerald

    // MARK: - Text (rich contrast on light)
    static let textPrimary = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let textSecondary = Color(red: 0.35, green: 0.36, blue: 0.42)
    static let textTertiary = Color(red: 0.55, green: 0.56, blue: 0.62)

    // MARK: - Surfaces (luminous, airy)
    static let surfacePrimary = Color(white: 1.0, opacity: 0.75)
    static let surfaceSecondary = Color(white: 0.96, opacity: 0.8)
    static let surfaceElevated = Color(white: 1.0, opacity: 0.9)
    static let surfaceHover = Color(red: 0.22, green: 0.45, blue: 1.0, opacity: 0.06)

    // MARK: - Borders
    static let borderSubtle = Color(white: 0.0, opacity: 0.08)
    static let borderActive = Color(red: 0.22, green: 0.45, blue: 1.0, opacity: 0.4)

    // MARK: - Backgrounds
    static let backgroundPrimary = Color(red: 0.965, green: 0.97, blue: 0.98)
    static let backgroundGradientStart = Color(red: 0.94, green: 0.95, blue: 0.99)
    static let backgroundGradientMid = Color(red: 0.96, green: 0.94, blue: 0.99)
    static let backgroundGradientEnd = Color(red: 0.93, green: 0.97, blue: 0.97)

    // MARK: - Terminal (code blocks keep dark for readability)
    static let terminalBg = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let terminalText = Color(red: 0.85, green: 0.87, blue: 0.90)
    static let terminalGreen = Color(red: 0.30, green: 0.85, blue: 0.50)

    // MARK: - Agent Colors
    static func agentColor(for name: String) -> Color {
        let colors: [Color] = [
            accentPrimary, accentSecondary, accentTertiary,
            .orange, .pink, .cyan, .indigo, .mint, .teal,
            Color(red: 0.9, green: 0.4, blue: 0.3)
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    // MARK: - Hero Gradient
    static let heroGradient = LinearGradient(
        colors: [accentPrimary, accentSecondary, accentTertiary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleGradient = LinearGradient(
        colors: [backgroundGradientStart, backgroundGradientMid, backgroundGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Dimensions
    static let cornerRadius: CGFloat = 14
    static let cornerRadiusSmall: CGFloat = 10
    static let cornerRadiusLarge: CGFloat = 18

    static let paddingSmall: CGFloat = 6
    static let paddingMedium: CGFloat = 12
    static let paddingLarge: CGFloat = 20

    static let sidebarWidth: CGFloat = 260
    static let inspectorWidth: CGFloat = 300
}

// MARK: - Glass Modifiers (Light)

struct GlassCard: ViewModifier {
    var isSelected: Bool = false
    var cornerRadius: CGFloat = GlassTheme.cornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white)
                    .shadow(color: .black.opacity(isSelected ? 0.10 : 0.04), radius: isSelected ? 12 : 6, y: isSelected ? 4 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isSelected ? GlassTheme.borderActive : GlassTheme.borderSubtle,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
    }
}

struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusLarge)
                    .fill(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusLarge)
                    .strokeBorder(GlassTheme.borderSubtle, lineWidth: 0.5)
            )
    }
}

struct GlassButton: ViewModifier {
    var isActive: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isActive
                ? GlassTheme.accentPrimary.opacity(0.08)
                : Color.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusSmall)
                    .strokeBorder(
                        isActive ? GlassTheme.borderActive : GlassTheme.borderSubtle,
                        lineWidth: isActive ? 1 : 0.5
                    )
            )
            .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

struct GlassTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusSmall)
                    .strokeBorder(GlassTheme.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(isSelected: Bool = false, cornerRadius: CGFloat = GlassTheme.cornerRadius) -> some View {
        modifier(GlassCard(isSelected: isSelected, cornerRadius: cornerRadius))
    }

    func glassPanel() -> some View {
        modifier(GlassPanel())
    }

    func glassButton(isActive: Bool = false) -> some View {
        modifier(GlassButton(isActive: isActive))
    }

    func glassTextField() -> some View {
        modifier(GlassTextField())
    }
}

// MARK: - Status Indicator

struct StatusDot: View {
    let status: SessionStatus
    var size: CGFloat = 8

    var color: Color {
        switch status {
        case .idle: return GlassTheme.textTertiary
        case .running: return GlassTheme.accentSuccess
        case .paused: return GlassTheme.accentWarning
        case .completed: return GlassTheme.accentPrimary
        case .error: return GlassTheme.accentError
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: size * 2, height: size * 2)
                    .opacity(status == .running ? 1 : 0)
                    .scaleEffect(status == .running ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: status)
            )
    }
}

// MARK: - Section Header

struct GlassSectionHeader: View {
    let title: String
    var icon: String? = nil
    var action: (() -> Void)? = nil
    var actionIcon: String = "plus"

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(GlassTheme.accentPrimary)
            }
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(GlassTheme.textTertiary)
                .textCase(.uppercase)
                .tracking(1.0)
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(GlassTheme.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, GlassTheme.paddingMedium)
        .padding(.vertical, GlassTheme.paddingSmall)
        .padding(.top, 6)
    }
}

// MARK: - Badge

struct GlassBadge: View {
    let text: String
    var color: Color = GlassTheme.accentPrimary

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}
