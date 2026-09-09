import SwiftUI

struct StopSearchView: View {
    @ObservedObject var model: AppModel
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var results: [StopMatch] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button(action: { isPresented = false }) {
                    Image("chevron-left").renderingMode(.template)
                        .resizable().aspectRatio(contentMode: .fit)
                        .foregroundColor(Color(white: 0.29))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                Text("Search stop").font(.sbb(16, weight: .bold)).foregroundColor(.inkPrimary)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))

            HStack(spacing: 8) {
                Image("magnifying-glass").renderingMode(.template)
                    .resizable().aspectRatio(contentMode: .fit)
                    .foregroundColor(.inkSecondary)
                    .frame(width: 17, height: 17)
                TextField("Stop name", text: $query)
                    .textFieldStyle(.plain)
                    .font(.sbb(15))
                    .onChange(of: query) { newValue in
                        // Single-parameter closure: the two-parameter
                        // (oldValue, newValue) onChange overload requires
                        // macOS 14+; this project's deployment target is
                        // macOS 13.0 (set in Task 1's project.yml).
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            guard !Task.isCancelled else { return }
                            results = (try? await model.search(newValue)) ?? []
                        }
                    }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Color.fieldBackground)
            .cornerRadius(8)
            .padding(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))

            Divider().overlay(Color.dividerLight)

            if !results.isEmpty {
                Text("\(results.count) match\(results.count == 1 ? "" : "es")")
                    .font(.sbb(10, weight: .bold))
                    .foregroundColor(.inkSecondary)
                    .tracking(1)
                    .padding(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
            }

            ForEach(Array(results.enumerated()), id: \.element) { index, match in
                Button(action: {
                    Task {
                        await model.selectStop(match)
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 12) {
                        Image("station").renderingMode(.template)
                            .resizable().aspectRatio(contentMode: .fit)
                            .foregroundColor(Color(white: 0.29))
                            .frame(width: 20, height: 20)
                        Text(match.name)
                            .font(.sbb(15, weight: index == 0 ? .bold : .regular))
                            .foregroundColor(.inkPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))
                    .background(index == 0 ? Color(white: 0.96) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().overlay(Color.dividerFaint)
            }
        }
        .frame(width: 320)
    }
}
