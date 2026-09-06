import SwiftUI

/// Minimal block-level Markdown renderer for the bundled legal documents.
///
/// SwiftUI's `Text` auto-parses Markdown only for string *literals*, never for
/// a runtime `String`, and it never handles block elements (headings, lists,
/// block quotes) regardless. This walks the source line by line, styles each
/// block, and resolves inline emphasis + links per line with
/// `AttributedString(markdown:)`. No third-party dependency.
struct MarkdownText: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
    }

    // MARK: Blocks

    private enum Block {
        case heading(AttributedString, level: Int)
        case paragraph(AttributedString)
        case bullet(AttributedString)
        case quote(AttributedString)
        case gap

        @ViewBuilder var view: some View {
            switch self {
            case let .heading(text, level):
                Text(text)
                    .font(level <= 1 ? .title2.weight(.bold)
                          : level == 2 ? .title3.weight(.semibold)
                          : .headline)
                    .padding(.top, level <= 2 ? 8 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            case let .paragraph(text):
                Text(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            case let .bullet(text):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").font(.body).foregroundStyle(.secondary)
                    Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
                }
            case let .quote(text):
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(.quaternary)
                            .frame(width: 3)
                    }
            case .gap:
                Color.clear.frame(height: 1)
            }
        }
    }

    private var blocks: [Block] {
        source.components(separatedBy: .newlines).map { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return .gap }
            if line.hasPrefix("### ") { return .heading(inline(line.dropFirst(4)), level: 3) }
            if line.hasPrefix("## ")  { return .heading(inline(line.dropFirst(3)), level: 2) }
            if line.hasPrefix("# ")   { return .heading(inline(line.dropFirst(2)), level: 1) }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { return .bullet(inline(line.dropFirst(2))) }
            if line.hasPrefix("> ")   { return .quote(inline(line.dropFirst(2))) }
            return .paragraph(inline(line))
        }
    }

    private func inline<S: StringProtocol>(_ s: S) -> AttributedString {
        (try? AttributedString(
            markdown: String(s),
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(String(s))
    }
}
