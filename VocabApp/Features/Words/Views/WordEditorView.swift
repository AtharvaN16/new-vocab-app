import SwiftUI

struct WordEditorView: View {
    @State var viewModel: WordEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: EditorFocus?

    @State private var newDefinitionText = ""
    @State private var newDefinitionPOS = ""
    @State private var newExampleText = ""
    @State private var newSynonymText = ""
    @State private var newAntonymText = ""

    private enum EditorFocus: Hashable {
        case definition, example, synonym, antonym, phonetic, etymology, contextNote
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Word title (non-editable)
                    Text(viewModel.original.word.capitalized)
                        .font(.system(size: 28, weight: .black))
                        .tracking(-1)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    editorSection("PRONUNCIATION") {
                        HStack(spacing: 8) {
                            TextField("e.g. SEP-uh-rayt", text: $viewModel.draftPhonetic)
                                .font(.system(size: 16))
                                .focused($focusedField, equals: .phonetic)
                            aiSuggestButton(.phonetic)
                        }
                        .padding(12)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.border))
                    }

                    editorSection("DEFINITIONS") {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.draftDefinitions.enumerated()), id: \.offset) { i, def in
                                HStack(alignment: .top, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if !def.partOfSpeech.isEmpty {
                                            Text(def.partOfSpeech)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                        Text(def.text)
                                            .font(.system(size: 15))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                    }
                                    Spacer()
                                    Button {
                                        viewModel.removeDefinition(at: IndexSet(integer: i))
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                    }
                                }
                                .padding(.vertical, 10)
                                if i < viewModel.draftDefinitions.count - 1 {
                                    Divider().padding(.leading, 0)
                                }
                            }
                            Divider()
                            HStack(spacing: 8) {
                                TextField("Add definition…", text: $newDefinitionText, axis: .vertical)
                                    .font(.system(size: 15))
                                    .focused($focusedField, equals: .definition)
                                    .lineLimit(1...3)
                                if !newDefinitionText.isEmpty {
                                    Button {
                                        viewModel.addDefinition(newDefinitionText)
                                        newDefinitionText = ""
                                        focusedField = nil
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(Theme.Colors.amieBlue)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 12)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.border))

                        aiSuggestButton(.definitions, label: "Suggest more")
                    }

                    editorSection("EXAMPLES") {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.draftExamples.enumerated()), id: \.offset) { i, ex in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\"\(ex.text)\"")
                                        .font(.system(size: 15))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .italic()
                                    Spacer()
                                    Button {
                                        viewModel.removeExample(at: IndexSet(integer: i))
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                    }
                                }
                                .padding(.vertical, 10)
                                if i < viewModel.draftExamples.count - 1 { Divider() }
                            }
                            Divider()
                            HStack(spacing: 8) {
                                TextField("Add example…", text: $newExampleText, axis: .vertical)
                                    .font(.system(size: 15))
                                    .focused($focusedField, equals: .example)
                                    .lineLimit(1...3)
                                if !newExampleText.isEmpty {
                                    Button {
                                        viewModel.addExample(newExampleText)
                                        newExampleText = ""
                                        focusedField = nil
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(Theme.Colors.amieBlue)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 12)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.border))

                        aiSuggestButton(.examples, label: "Generate 3 examples")
                    }

                    editorSection("SYNONYMS") {
                        tagField(
                            tags: viewModel.draftSynonyms,
                            newTag: $newSynonymText,
                            focus: .synonym,
                            placeholder: "Add synonym…",
                            onAdd: { viewModel.addSynonym(newSynonymText); newSynonymText = "" },
                            onRemove: { viewModel.removeSynonym($0) }
                        )
                        aiSuggestButton(.synonyms, label: "Suggest more")
                    }

                    editorSection("ANTONYMS") {
                        tagField(
                            tags: viewModel.draftAntonyms,
                            newTag: $newAntonymText,
                            focus: .antonym,
                            placeholder: "Add antonym…",
                            onAdd: { viewModel.addAntonym(newAntonymText); newAntonymText = "" },
                            onRemove: { viewModel.removeAntonym($0) }
                        )
                        aiSuggestButton(.antonyms, label: "Suggest more")
                    }

                    editorSection("ETYMOLOGY") {
                        HStack(alignment: .top, spacing: 8) {
                            TextField("Etymology…", text: $viewModel.draftEtymology, axis: .vertical)
                                .font(.system(size: 15))
                                .focused($focusedField, equals: .etymology)
                                .lineLimit(2...5)
                            aiSuggestButton(.etymology)
                        }
                        .padding(12)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.border))
                    }

                    editorSection("CONTEXT NOTE") {
                        HStack(alignment: .top, spacing: 8) {
                            TextField("Usage context…", text: $viewModel.draftContextualNote, axis: .vertical)
                                .font(.system(size: 15))
                                .focused($focusedField, equals: .contextNote)
                                .lineLimit(2...5)
                            aiSuggestButton(.contextualNote)
                        }
                        .padding(12)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.border))
                    }

                    if let error = viewModel.suggestError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Theme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            do {
                                try await viewModel.save()
                                dismiss()
                            } catch {
                                viewModel.saveError = error.localizedDescription
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(viewModel.hasChanges ? Theme.Colors.amieBlue : Theme.Colors.textSecondary)
                        }
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isSaving)
                }
            }
        }
    }

    // MARK: - Reusable section

    @ViewBuilder
    private func editorSection<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(Theme.Colors.textSecondary)
            content()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - AI suggest button

    @ViewBuilder
    private func aiSuggestButton(_ field: WordField, label: String? = nil) -> some View {
        Button {
            Task { await viewModel.suggestForField(field) }
        } label: {
            HStack(spacing: 4) {
                if viewModel.suggestingField == field {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                }
                if let label {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundColor(Theme.Colors.amieBlue)
            .padding(.horizontal, label != nil ? 10 : 6)
            .padding(.vertical, 6)
            .background(Theme.Colors.amieBlue.opacity(0.1))
            .clipShape(Capsule())
        }
        .disabled(viewModel.suggestingField != nil)
    }

    // MARK: - Tag field (synonyms/antonyms)

    @ViewBuilder
    private func tagField(
        tags: [String],
        newTag: Binding<String>,
        focus: EditorFocus,
        placeholder: String,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.system(size: 14))
                        Button { onRemove(tag) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.iconBackground)
                    .clipShape(Capsule())
                    .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            HStack(spacing: 8) {
                TextField(placeholder, text: newTag)
                    .font(.system(size: 14))
                    .focused($focusedField, equals: focus)
                    .onSubmit {
                        onAdd()
                        focusedField = nil
                    }
                if !newTag.wrappedValue.isEmpty {
                    Button { onAdd(); focusedField = nil } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.Colors.amieBlue)
                    }
                }
            }
            .padding(10)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.border))
        }
    }
}

