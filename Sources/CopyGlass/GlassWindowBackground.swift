import AppKit
import SwiftUI

/// A native backdrop that blurs the desktop behind the window, rather than
/// fading the window's text and controls together with its background.
struct GlassWindowSurface: View {
    @AppStorage("liquidGlassEnabled") private var liquidGlassEnabled = true
    @AppStorage("backgroundTransparency") private var transparency = 75.0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var amount: Double {
        liquidGlassEnabled && !reduceTransparency ? min(max(transparency, 0), 100) / 100 : 0
    }

    var body: some View {
        ZStack {
            GlassWindowBackground(transparency: amount)
            Color(nsColor: .windowBackgroundColor).opacity(1 - amount)
            if amount > 0 {
                glassFinish
                    .opacity(amount)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.22 : 0.5), .white.opacity(0.02), .blue.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1)
                            .opacity(amount)
                    }
            }
        }.allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var glassFinish: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 16).fill(.clear)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
        } else {
            // Keep the desktop blur on older macOS versions, adding a subtle
            // reflective finish without lowering text or control opacity.
            LinearGradient(colors: [.white.opacity(0.14), .clear, .blue.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct GlassWindowBackground: NSViewRepresentable {
    let transparency: Double
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> WindowBackdrop {
        let view = WindowBackdrop()
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: WindowBackdrop, context: Context) {
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        view.reduceTransparency = transparency == 0
        view.isHidden = transparency == 0
        // Only the backdrop fades. Foreground content stays fully readable.
        view.alphaValue = 1 - 0.45 * pow(transparency, 2)
        view.configureWindow()
    }

    final class WindowBackdrop: NSVisualEffectView {
        var reduceTransparency = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }

        func configureWindow() {
            guard let window else { return }
            window.isOpaque = reduceTransparency
            window.backgroundColor = reduceTransparency ? .windowBackgroundColor : .clear
        }
    }
}
