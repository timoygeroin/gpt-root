import SwiftUI

/// The visual constitution of MONDAYID REALITY.
///
/// No arbitrary brand color is allowed to carry safety meaning. The surface is
/// semantic, adaptive, and inherits platform accessibility behavior.
enum RealitySurfacePhase: Equatable {
    case loading
    case unchanged
    case coverageIncomplete
    case active
    case activeUnverified
    case resolved
}

struct SurfacePalette {
    let background: Color
    let primary: Color
    let secondary: Color
    let accent: Color
    let material: Material

    static func palette(for phase: RealitySurfacePhase, contrast: AccessibilityContrast) -> SurfacePalette {
        let primary = Color.primary
        let secondary = Color.secondary
        switch phase {
        case .active, .activeUnverified:
            return SurfacePalette(background: Color(uiColor: .systemBackground), primary: primary, secondary: secondary, accent: .red, material: contrast == .increased ? .regularMaterial : .ultraThinMaterial)
        case .coverageIncomplete, .resolved, .loading, .unchanged:
            return SurfacePalette(background: Color(uiColor: .systemBackground), primary: primary, secondary: secondary, accent: .secondary, material: contrast == .increased ? .regularMaterial : .ultraThinMaterial)
        }
    }
}

struct StateGlyph: View {
    let phase: RealitySurfacePhase
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .accessibilityHidden(true)
            .overlay {
                if differentiateWithoutColor && (phase == .active || phase == .activeUnverified) {
                    Circle().stroke(lineWidth: 2).padding(-5)
                }
            }
    }

    private var symbol: String {
        switch phase {
        case .loading: return "ellipsis"
        case .unchanged: return "minus"
        case .coverageIncomplete: return "exclamationmark.triangle"
        case .active: return "exclamationmark.octagon.fill"
        case .activeUnverified: return "exclamationmark.octagon"
        case .resolved: return "checkmark"
        }
    }
}

struct PressFeedbackStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}
