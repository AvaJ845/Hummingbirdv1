import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let resourceName: String
    @Environment(\.dismiss) private var dismiss

    private var bodyText: String {
        AppLegal.bundledMarkdown(named: resourceName)
            ?? "\(title) could not be loaded. Please try again later."
    }

    var body: some View {
        ScrollView {
            Text(bodyText)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    NavigationMotion.pop(dismiss)
                }
            }
        }
    }
}
