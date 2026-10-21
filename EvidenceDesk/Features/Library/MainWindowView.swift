import SwiftUI
import SwiftData

@MainActor
struct MainWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Query(sort: \ResearchCase.updatedAt, order: .reverse) private var allCases: [ResearchCase]

    @State private var selectedCaseID: UUID?
    @State private var searchText = ""
    @State private var showArchived = false
    @State private var inspectorVisible = false

    @State private var newCasePresented = false
    @State private var importPresented = false

    /// QA hooks so empty/search states can be captured deterministically
    /// (text entry goes through the user's input method, which is not
    /// reproducible in automation):
    ///   `--ed-show-archived`   show the archived library
    ///   `--ed-search <text>`   pre-fill the library search
    private func applyLaunchState() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ed-show-archived") {
            showArchived = true
        }
        if let index = args.firstIndex(of: "--ed-search"), index + 1 < args.count {
            searchText = args[index + 1]
        }
    }

    private var filteredCases: [ResearchCase] {
        CaseFilter.apply(to: allCases, showArchived: showArchived, query: searchText)
    }

    var body: some View {
        NavigationSplitView(sidebar: {
            LibrarySidebarView(
                cases: filteredCases,
                searchText: $searchText,
                showArchived: $showArchived,
                selection: $selectedCaseID,
                onNewCase: { newCasePresented = true }
            )
            .navigationSplitViewColumnWidth(DesignSystem.Layout.sidebarWidth)
        }, detail: {
            if let selectedCaseID, let selected = allCases.first(where: { $0.id == selectedCaseID }) {
                CaseWorkspaceView(researchCase: selected, inspectorVisible: $inspectorVisible)
            } else {
                EmptyStateView(
                    systemImage: "square.stack.3d.up.slash",
                    title: "Select a Research Case",
                    message: "Choose a case from the library, or create a new one to begin collecting evidence.",
                    actionTitle: "New Research Case",
                    action: { newCasePresented = true }
                )
            }
        })
        .searchable(text: $searchText, placement: .sidebar)
        .designAware()
        .sheet(isPresented: $newCasePresented) {
            AddCaseSheet { created in
                newCasePresented = false
                selectedCaseID = created.id
            } onCancel: {
                newCasePresented = false
            }
        }
        .sheet(isPresented: $importPresented) {
            if let selectedCaseID, let selected = allCases.first(where: { $0.id == selectedCaseID }) {
                AddSourceSheet(researchCase: selected) {
                    importPresented = false
                }
            }
        }
        .onAppear {
            applyLaunchState()
            // Select the most recent case by default so the workspace is usable
            // immediately (also used by seeded QA screenshots).
            if selectedCaseID == nil, let first = allCases.first(where: { !$0.isArchived }) {
                selectedCaseID = first.id
            }
        }
        .onReceive(AppActions.shared.publisher()) { action in
            switch action {
            case .newCase:
                newCasePresented = true
            case .importSource:
                guard let selectedCaseID, allCases.contains(where: { $0.id == selectedCaseID }) else {
                    // Ensure a selection exists before importing.
                    if let first = allCases.first(where: { !$0.isArchived }) {
                        selectedCaseID = first.id
                        importPresented = true
                    }
                    return
                }
                importPresented = true
            case .exportReport, .focusSearch, .toggleSidebar, .showLibraryList:
                break // handled by their owning views
            case .toggleInspector:
                inspectorVisible.toggle()
            }
        }
    }
}