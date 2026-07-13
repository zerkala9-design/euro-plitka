import SwiftUI
import UIKit
import PhilipsKit

/// Ambilight control center: power, mode presets, brightness/saturation sliders
/// and a color wheel for static colors. Only shown for TVs that support it.
struct AmbilightView: View {
    @Environment(TVController.self) private var controller
    @State private var color = Color(red: 0, green: 0.48, blue: 1)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    powerCard
                    modeGrid
                    slidersCard
                    colorCard
                }
                .padding()
                .disabled(!controller.ambilight.power)
                .animation(.smooth, value: controller.ambilight.power)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Ambilight")
            .task { await controller.refreshAmbilight() }
        }
    }

    private var powerCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ambilight").font(.headline)
                    Text(controller.ambilight.power ? "On" : "Off")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { controller.ambilight.power },
                    set: { on in Task { await controller.setAmbilightPower(on) } }
                ))
                .labelsHidden()
            }
        }
        .disabled(false)
    }

    private var modeGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(AmbilightState.Mode.allCases) { mode in
                Button {
                    Haptics.shared.selectionChanged()
                    Task { await controller.setAmbilightMode(mode) }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: mode.systemImage).font(.title2)
                        Text(mode.title).font(.caption).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .background(controller.ambilight.mode == mode ? AnyShapeStyle(.tint.opacity(0.3)) : AnyShapeStyle(.ultraThinMaterial),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(controller.ambilight.mode == mode ? Color.accentColor : .white.opacity(0.1),
                                      lineWidth: controller.ambilight.mode == mode ? 2 : 1))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
    }

    private var slidersCard: some View {
        GlassCard {
            VStack(spacing: 18) {
                labeledSlider("Brightness", systemImage: "sun.max.fill",
                              value: Binding(
                                get: { Double(controller.ambilight.brightness) },
                                set: { controller.ambilight.brightness = Int($0) }),
                              range: 0...255)
                labeledSlider("Saturation", systemImage: "drop.fill",
                              value: Binding(
                                get: { Double(controller.ambilight.saturation) },
                                set: { controller.ambilight.saturation = Int($0) }),
                              range: 0...255)
            }
        }
    }

    private var colorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Static Color").font(.headline)
                ColorPicker("Pick a color", selection: $color, supportsOpacity: false)
                    .onChange(of: color) { _, new in
                        Task { await controller.setAmbilightColor(new.rgb) }
                    }
                HStack {
                    ForEach(AmbilightPreset.all) { preset in
                        Button {
                            color = preset.color
                            Task { await controller.setAmbilightColor(preset.color.rgb) }
                        } label: {
                            Circle().fill(preset.color).frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(.white.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func labeledSlider(_ title: String, systemImage: String,
                               value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage).font(.subheadline)
            Slider(value: value, in: range)
                .tint(.accentColor)
        }
    }
}

struct AmbilightPreset: Identifiable {
    let id = UUID()
    let color: Color
    static let all: [AmbilightPreset] = [
        .init(color: .red), .init(color: .orange), .init(color: .yellow),
        .init(color: .green), .init(color: .blue), .init(color: .purple), .init(color: .white)
    ]
}

extension Color {
    /// Convert to the API's 0…255 RGB model.
    var rgb: RGBColor {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBColor(r: Int(r * 255), g: Int(g * 255), b: Int(b * 255))
    }
}
