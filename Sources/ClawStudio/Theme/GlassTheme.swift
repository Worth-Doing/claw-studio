import SwiftUI

// MARK: - Adaptive Glass UI Design System (Light + Dark)

enum GlassTheme {
    // MARK: - Accent Palette (vivid, premium — same in both modes)
    static let accentPrimary = Color(red: 0.22, green: 0.45, blue: 1.0)
    static let accentSecondary = Color(red: 0.52, green: 0.32, blue: 0.98)
    static let accentTertiary = Color(red: 0.0, green: 0.78, blue: 0.72)
    static let accentWarning = Color(red: 0.96, green: 0.65, blue: 0.14)
    static let accentError = Color(red: 0.95, green: 0.28, blue: 0.28)
    static let accentSuccess = Color(red: 0.15, green: 0.78, blue: 0.42)

    // MARK: - Adaptive Text
    static let textPrimary = Color("textPrimary", bundle: nil)
    static let textSecondary = Color("textSecondary", bundle: nil)
    static let textTertiary = Color("textTertiary", bundle: nil)

    // MARK: - Adaptive Surfaces
    static let surfacePrimary = Color("surfacePrimary", bundle: nil)
    static let surfaceSecondary = Color("surfaceSecondary", bundle: nil)
    static let surfaceElevated = Color("surfaceElevated", bundle: nil)
    static let surfaceHover = Color("surfaceHover", bundle: nil)

    // MARK: - Adaptive Borders
    static let borderSubtle = Color("borderSubtle", bundle: nil)
    static let borderActive = Color(red: 0.22, green: 0.45, blue: 1.0, opacity: 0.4)

    // MARK: - Adaptive Backgrounds
    static let backgroundPrimary = Color("backgroundPrimary", bundle: nil)

    // MARK: - Terminal (always dark)
    static let terminalBg = Color(red: 0.10, green: 0.10, blue: 0.13)
    static let terminalText = Color(red: 0.85, green: 0.87, blue: 0.90)
    static let terminalGreen = Color(red: 0.30, green: 0.85, blue: 0.50)

    // MARK: - Sidebar
    static let sidebarBackground = Color("sidebarBackground", bundle: nil)
    static let headerBackground = Color("headerBackground", bundle: nil)
    static let cardBackground = Color("cardBackground", bundle: nil)

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

    static var subtleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color("gradientStart", bundle: nil),
                Color("gradientMid", bundle: nil),
                Color("gradientEnd", bundle: nil)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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

// MARK: - Resolved Theme (for use in modifiers that need concrete values)

struct ResolvedTheme {
    let colorScheme: ColorScheme

    var cardFill: Color {
        colorScheme == .dark
            ? Color(white: 0.16, opacity: 0.9)
            : Color.white
    }

    var cardShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.3)
            : Color.black.opacity(0.04)
    }

    var cardSelectedShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.4)
            : Color.black.opacity(0.10)
    }

    var panelFill: Color {
        colorScheme == .dark
            ? Color(white: 0.14, opacity: 0.85)
            : Color.white.opacity(0.85)
    }

    var buttonFill: Color {
        colorScheme == .dark
            ? Color(white: 0.2, opacity: 0.6)
            : Color.white.opacity(0.6)
    }

    var buttonActiveFill: Color {
        GlassTheme.accentPrimary.opacity(colorScheme == .dark ? 0.15 : 0.08)
    }

    var textFieldFill: Color {
        colorScheme == .dark
            ? Color(white: 0.15)
            : Color.white
    }
}

// MARK: - Glass Modifiers (Adaptive)

struct GlassCard: ViewModifier {
    var isSelected: Bool = false
    var cornerRadius: CGFloat = GlassTheme.cornerRadius
    @Environment(\.colorScheme) private var colorScheme

    private var resolved: ResolvedTheme { ResolvedTheme(colorScheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(resolved.cardFill)
                    .shadow(
                        color: isSelected ? resolved.cardSelectedShadowColor : resolved.cardShadowColor,
                        radius: isSelected ? 12 : 6,
                        y: isSelected ? 4 : 2
                    )
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
    @Environment(\.colorScheme) private var colorScheme

    private var resolved: ResolvedTheme { ResolvedTheme(colorScheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusLarge)
                    .fill(resolved.panelFill)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusLarge)
                    .strokeBorder(GlassTheme.borderSubtle, lineWidth: 0.5)
            )
    }
}

struct GlassButton: ViewModifier {
    var isActive: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var resolved: ResolvedTheme { ResolvedTheme(colorScheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isActive ? resolved.buttonActiveFill : resolved.buttonFill)
            .clipShape(RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusSmall)
                    .strokeBorder(
                        isActive ? GlassTheme.borderActive : GlassTheme.borderSubtle,
                        lineWidth: isActive ? 1 : 0.5
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.03), radius: 2, y: 1)
    }
}

struct GlassTextField: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var resolved: ResolvedTheme { ResolvedTheme(colorScheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(10)
            .background(resolved.textFieldFill)
            .clipShape(RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadiusSmall)
                    .strokeBorder(GlassTheme.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.03), radius: 2, y: 1)
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
    @State private var isAnimating = false

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
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
            )
            .onAppear {
                if status == .running {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
            .onChange(of: status) { _, newValue in
                if newValue == .running {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                } else {
                    isAnimating = false
                }
            }
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

// MARK: - Adaptive Color Definitions (fallback when asset catalog unavailable)

extension Color {
    init(_ name: String, bundle: Bundle?) {
        // Since we're a Swift Package without asset catalogs,
        // use programmatic adaptive colors
        switch name {
        // Text
        case "textPrimary":
            self.init(light: Color(red: 0.08, green: 0.08, blue: 0.12),
                      dark: Color(red: 0.93, green: 0.93, blue: 0.96))
        case "textSecondary":
            self.init(light: Color(red: 0.35, green: 0.36, blue: 0.42),
                      dark: Color(red: 0.65, green: 0.66, blue: 0.72))
        case "textTertiary":
            self.init(light: Color(red: 0.55, green: 0.56, blue: 0.62),
                      dark: Color(red: 0.45, green: 0.46, blue: 0.52))

        // Surfaces
        case "surfacePrimary":
            self.init(light: Color(white: 1.0, opacity: 0.75),
                      dark: Color(white: 0.15, opacity: 0.75))
        case "surfaceSecondary":
            self.init(light: Color(white: 0.96, opacity: 0.8),
                      dark: Color(white: 0.18, opacity: 0.8))
        case "surfaceElevated":
            self.init(light: Color(white: 1.0, opacity: 0.9),
                      dark: Color(white: 0.20, opacity: 0.9))
        case "surfaceHover":
            self.init(light: Color(red: 0.22, green: 0.45, blue: 1.0, opacity: 0.06),
                      dark: Color(red: 0.22, green: 0.45, blue: 1.0, opacity: 0.12))

        // Borders
        case "borderSubtle":
            self.init(light: Color(white: 0.0, opacity: 0.08),
                      dark: Color(white: 1.0, opacity: 0.10))

        // Backgrounds
        case "backgroundPrimary":
            self.init(light: Color(red: 0.965, green: 0.97, blue: 0.98),
                      dark: Color(red: 0.08, green: 0.08, blue: 0.10))

        // Gradients
        case "gradientStart":
            self.init(light: Color(red: 0.94, green: 0.95, blue: 0.99),
                      dark: Color(red: 0.08, green: 0.08, blue: 0.12))
        case "gradientMid":
            self.init(light: Color(red: 0.96, green: 0.94, blue: 0.99),
                      dark: Color(red: 0.09, green: 0.07, blue: 0.12))
        case "gradientEnd":
            self.init(light: Color(red: 0.93, green: 0.97, blue: 0.97),
                      dark: Color(red: 0.07, green: 0.09, blue: 0.10))

        // Structural
        case "sidebarBackground":
            self.init(light: Color.white.opacity(0.7),
                      dark: Color(white: 0.11, opacity: 0.9))
        case "headerBackground":
            self.init(light: Color.white.opacity(0.7),
                      dark: Color(white: 0.13, opacity: 0.9))
        case "cardBackground":
            self.init(light: Color.white,
                      dark: Color(white: 0.16))

        default:
            self = .clear
        }
    }

    /// Create an adaptive color that resolves differently for light and dark modes
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}
