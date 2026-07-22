import SwiftUI

@MainActor
struct AgentPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var teslaFiStore: TeslaFiSessionStore
    @Environment(\.appThemeBox) private var themeBox

    @AppStorage("agent.enabled") private var agentEnabled: Bool = true

    @State private var prompt: String = ""
    @State private var response: AgentResponse?
    @State private var isRunning: Bool = false
    @State private var showConfirmAction: Bool = false

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard

                    if !agentEnabled {
                        disabledCard
                    } else {
                        promptCard
                        suggestionsCard
                        responseCard
                    }
                }
                .padding(16)
            }
            .navigationTitle("AI Copilot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog(
                "Apply this draft action?",
                isPresented: $showConfirmAction,
                titleVisibility: .visible
            ) {
                Button("Apply") { applyProposedAction() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(response?.proposedAction?.detail ?? "")
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Task-focused assistant")
                .font(.headline)
            Text("Grounded in your local stores: entries, vehicle profile, and imported charging sessions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var disabledCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Copilot is disabled")
                .font(.headline)
            Text("Enable it in Settings > Agent to use summaries and action drafts.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Toggle("Enable Agent", isOn: $agentEnabled)
                .tint(theme.accent)
        }
        .themedCard()
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ask for summary, spike check, cheaper windows, missing costs, or draft expense", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            Button {
                Task { await runPrompt(prompt) }
            } label: {
                HStack {
                    if isRunning { ProgressView().controlSize(.small) }
                    Text(isRunning ? "Running…" : "Run")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .disabled(isRunning || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .themedCard()
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick prompts")
                .font(.subheadline.weight(.semibold))

            ForEach(samplePrompts, id: \.self) { item in
                Button(item) { prompt = item }
                    .font(.footnote)
            }
        }
        .themedCard()
    }

    @ViewBuilder
    private var responseCard: some View {
        if let response {
            VStack(alignment: .leading, spacing: 10) {
                Text("Response")
                    .font(.headline)
                Text(response.text)
                    .font(.subheadline)

                if !response.dataUsed.isEmpty {
                    Text("Data used")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(response.dataUsed, id: \.self) { line in
                        Text("• \(line)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let proposed = response.proposedAction {
                    Divider().opacity(0.2)
                    Text(proposed.title)
                        .font(.subheadline.weight(.semibold))
                    Text(proposed.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Apply Action") { showConfirmAction = true }
                        .buttonStyle(.bordered)
                }
            }
            .themedCard()
        }
    }

    private var samplePrompts: [String] {
        [
            "Summarize my last 7 days",
            "Monthly breakdown so far",
            "Detect cost spike",
            "Where does this owner charge most often?",
            "What is affecting long-term battery health?",
            "Give me concrete battery suggestions",
            "Suggest cheaper charging window",
            "Show missing costs",
            "Draft expense"
        ]
    }

    private func runPrompt(_ text: String) async {
        isRunning = true
        defer { isRunning = false }

        let contextBuilder = AgentContextBuilder(
            entriesStore: entriesStore,
            profileStore: profileStore,
            teslaFiStore: teslaFiStore
        )
        let tools = AgentTools(entriesStore: entriesStore, teslaFiStore: teslaFiStore)
        let orchestrator = AgentOrchestrator(contextBuilder: contextBuilder, tools: tools)

        response = await orchestrator.run(query: text)
    }

    private func applyProposedAction() {
        guard let action = response?.proposedAction?.action else { return }
        let executor = AgentActionExecutor(entriesStore: entriesStore)
        executor.execute(action)
    }
}
