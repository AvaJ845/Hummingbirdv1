import SwiftUI

/// Full-screen black bloom that expands from the microphone, with live transcript
/// and a send → checkmark action that rotates as listening locks in.
struct DictationOverlay: View {
    let bloomProgress: CGFloat
    let actionRotation: Double
    let phase: DictationController.Phase
    let transcript: String
    let micCenter: CGPoint
    let onConfirm: () -> Void
    let onCancel: () -> Void

    /// Bloom circle diameter — derived from the container size (below) rather
    /// than `UIScreen.main.bounds` so it stays correct on iPad and in any
    /// resized window, not just a fixed full screen.
    private func diameter(for size: CGSize) -> CGFloat {
        max(size.width, size.height) * 2.4
    }

    private var canConfirm: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GeometryReader { geo in
            let center = micCenter == .zero
                ? CGPoint(x: geo.size.width - 40, y: geo.size.height - 120)
                : micCenter

            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: diameter(for: geo.size), height: diameter(for: geo.size))
                    .scaleEffect(max(0.001, bloomProgress))
                    .position(center)
                    .opacity(Double(min(1, bloomProgress * 1.2)))
                    .ignoresSafeArea()

                if bloomProgress > 0.35 {
                    VStack(spacing: 24) {
                        Spacer()

                        listeningChrome

                        Text(transcript.isEmpty ? "Speak a ticker or coin…" : transcript)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: transcript)

                        Text(phaseLabel)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.55))

                        Text("Fills the ticker field — same as typing.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        Spacer()

                        HStack(spacing: 36) {
                            Button(action: onCancel) {
                                Image(systemName: "xmark")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(.white.opacity(0.12)))
                            }
                            .accessibilityLabel("Cancel dictation")

                            Button(action: onConfirm) {
                                ZStack {
                                    Circle()
                                        .fill(canConfirm ? Theme.accent : Theme.accent.opacity(0.35))
                                        .frame(width: 72, height: 72)
                                        .shadow(color: Theme.accent.opacity(canConfirm ? 0.45 : 0), radius: 16, y: 6)

                                    Image(systemName: showCheckmark ? "checkmark" : "arrow.up")
                                        .font(.title.weight(.bold))
                                        .foregroundStyle(.black)
                                        .rotationEffect(.degrees(actionRotation))
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }
                            .accessibilityLabel(showCheckmark ? "Use dictated symbol" : "Send")
                            .disabled(!canConfirm)
                        }
                        .padding(.bottom, 48)
                    }
                    .transition(.opacity)
                }
            }
        }
        .allowsHitTesting(bloomProgress > 0.2)
    }

    private var showCheckmark: Bool {
        phase == .listening || phase == .confirming || actionRotation >= 90
    }

    private var phaseLabel: String {
        switch phase {
        case .blooming: "Starting…"
        case .listening: "Listening"
        case .confirming: "Got it"
        case .collapsing: ""
        case .idle: ""
        }
    }

    private var listeningChrome: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 2)
                .frame(width: 96, height: 96)
                .scaleEffect(phase == .listening ? 1.15 : 1)
                .opacity(phase == .listening ? 0.5 : 0.2)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: phase)

            Image(systemName: "mic.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: phase == .listening)
        }
    }
}

/// Preference for the microphone button's global center.
struct MicAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
