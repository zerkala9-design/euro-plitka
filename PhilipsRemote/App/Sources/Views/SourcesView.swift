import SwiftUI
import PhilipsKit

/// Input source picker with rename & favorite support.
struct SourcesView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: InputSource?
    @State private var newName = ""

    private var sources: [InputSource] {
        controller.sources.map { source in
            var s = source
            s.customName = AppPreferences.inputName(for: source.id)
            s.isFavorite = AppPreferences.isInputFavorite(source.id)
            return s
        }
        .sorted { ($0.isFavorite ? 0 : 1, $0.displayName) < ($1.isFavorite ? 0 : 1, $1.displayName) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if sources.isEmpty {
                        ContentUnavailableView("No inputs reported",
                                               systemImage: "cable.connector",
                                               description: Text("This TV didn't expose switchable inputs over the API."))
                            .padding(.top, 60)
                    }
                    ForEach(sources) { source in
                        sourceRow(source)
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { await controller.refreshSources() }
            .alert("Rename input", isPresented: Binding(get: { renaming != nil },
                                                        set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Save") {
                    if let renaming { AppPreferences.setInputName(newName, for: renaming.id) }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func sourceRow(_ source: InputSource) -> some View {
        Button {
            Haptics.shared.tap()
            Task { await controller.selectSource(source); dismiss() }
        } label: {
            GlassCard(cornerRadius: Theme.cornerRadiusMedium, padding: 14) {
                HStack(spacing: 14) {
                    Image(systemName: source.kind.systemImage)
                        .font(.title2).foregroundStyle(.tint).frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.displayName).font(.headline)
                        Text(source.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        AppPreferences.toggleInputFavorite(source.id)
                        Haptics.shared.selectionChanged()
                    } label: {
                        Image(systemName: source.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(source.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                newName = source.displayName
                renaming = source
            } label: { Label("Rename", systemImage: "pencil") }
        }
    }
}
