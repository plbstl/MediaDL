import SwiftUI
import UniformTypeIdentifiers

struct ModelSetupView: View {
    @State private var store = ModelStore.shared
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "waveform")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("MediaDL Speech")
                    .font(.largeTitle.bold())

                Text("Choose one compatible speech model. Download it or import a prepared model folder from Files. Transcription runs on this iPhone.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Picker("Selected model", selection: $store.selectedModelID) {
                    ForEach(SpeechModelID.allCases) { model in
                        Text(model.title).tag(model.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("speechModelPicker")

                modelDetails(for: store.selectedModel)

                if let error = store.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("modelError")
                }

                Button {
                    Task { await store.downloadSelectedModel() }
                } label: {
                    if store.isBusy {
                        ProgressView(store.status)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(store.selectedModelIsInstalled ? "Recheck Model" : "Download Model")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isBusy)

                Button("Import Model Folder from Files") {
                    isImporting = true
                }
                .buttonStyle(.bordered)
                .disabled(store.isBusy)
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        Task { await store.importModel(from: url) }
                    case .failure(let error):
                        store.errorMessage = "Could not open the selected folder: \(error.localizedDescription)"
                    }
                }

                if store.selectedModelIsInstalled {
                    Button("Delete Selected Model", role: .destructive) {
                        store.deleteSelectedModel()
                    }
                    .disabled(store.isBusy)
                }

                Label(store.status, systemImage: store.selectedModelIsInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("modelStatus")

                Text("Only the selected model is used for default transcription. Other existing model files are preserved until you delete them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func modelDetails(for model: SpeechModelID) -> some View {
        VStack(spacing: 10) {
            Label(store.selectedModelIsInstalled ? "Installed and ready offline" : "Not installed", systemImage: store.selectedModelIsInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.headline)
                .accessibilityIdentifier("selectedModelStatus")

            Text(model.description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text(model.sizeNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
