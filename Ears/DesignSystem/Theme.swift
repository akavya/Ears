//
//  Theme.swift
//  Ears
//
//  App-wide theming and styling
//

import SwiftUI

/// App-wide theme configuration
enum Theme {
    // MARK: - Colors

    /// Primary brand color
    static let primary = Color.accentColor

    /// Background colors
    enum Background {
        static let primary = Color(.systemBackground)
        static let secondary = Color(.secondarySystemBackground)
        static let tertiary = Color(.tertiarySystemBackground)
        static let grouped = Color(.systemGroupedBackground)
    }

    /// Text colors
    enum Text {
        static let primary = Color(.label)
        static let secondary = Color(.secondaryLabel)
        static let tertiary = Color(.tertiaryLabel)
        static let quaternary = Color(.quaternaryLabel)
    }

    /// Semantic colors
    enum Semantic {
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
    }

    // MARK: - Typography

    /// Custom font styles for consistent typography
    enum Typography {
        static let largeTitle = Font.largeTitle.bold()
        static let title = Font.title.bold()
        static let title2 = Font.title2.bold()
        static let title3 = Font.title3.bold()
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2

        /// Monospaced digits for times and numbers
        static let monospacedDigits = Font.body.monospacedDigit()
    }

    // MARK: - Spacing

    /// Consistent spacing values
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
        static let circle: CGFloat = 9999
    }

    // MARK: - Shadows

    enum Shadow {
        static func small(_ color: Color = .black.opacity(0.1)) -> some View {
            EmptyView().shadow(color: color, radius: 2, y: 1)
        }

        static func medium(_ color: Color = .black.opacity(0.15)) -> some View {
            EmptyView().shadow(color: color, radius: 4, y: 2)
        }

        static func large(_ color: Color = .black.opacity(0.2)) -> some View {
            EmptyView().shadow(color: color, radius: 8, y: 4)
        }
    }

    // MARK: - Animations

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
}

// MARK: - Bedroom Mode Theme

/// OLED-optimized dark theme for nighttime use
struct BedroomModeModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(enabled ? .dark : nil)
            .brightness(enabled ? -0.1 : 0)
    }
}

extension View {
    func bedroomMode(_ enabled: Bool) -> some View {
        modifier(BedroomModeModifier(enabled: enabled))
    }
}

// MARK: - Button Styles

/// Primary button style
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(isEnabled ? Theme.primary : Color.gray)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

/// Secondary button style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Theme.primary.opacity(0.1))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Card Style

struct CardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .fill(Theme.Background.secondary)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

extension View {
    func card(padding: CGFloat = Theme.Spacing.lg) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String?

    init(isLoading: Bool, message: String? = nil) {
        self.isLoading = isLoading
        self.message = message
    }

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .tint(.white)

                    if let message = message {
                        Text(message)
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                .padding(Theme.Spacing.xl)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            }
        }
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool, message: String? = nil) -> some View {
        overlay {
            LoadingOverlay(isLoading: isLoading, message: message)
        }
    }
}
