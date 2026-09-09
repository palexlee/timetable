import SwiftUI

struct APIKeyEntryView: View {
    @ObservedObject var model: AppModel
    @Binding var isPresented: Bool
    @State private var key = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button(action: { isPresented = false }) {
                    Image("chevron-left").renderingMode(.template).foregroundColor(Color(white: 0.29))
                }
                .buttonStyle(.plain)
                Text("API key").font(.sbb(16, weight: .bold)).foregroundColor(.inkPrimary)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Required to fetch live departures from opentransportdata.swiss.")
                    .font(.sbb(13))
                    .foregroundColor(.inkSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("API KEY").font(.sbb(10, weight: .bold)).foregroundColor(.inkSecondary).tracking(1)
                    HStack(spacing: 8) {
                        Image("key").renderingMode(.template).foregroundColor(.inkSecondary)
                        SecureField("", text: $key)
                            .textFieldStyle(.plain)
                            .font(.sbb(15))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .background(Color.fieldBackground)
                    .cornerRadius(8)
                }

                if let errorMessage {
                    Text(errorMessage).font(.sbb(12)).foregroundColor(.sbbRed)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.plain)
                        .padding(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.85)))
                    Button(action: {
                        do {
                            try model.setAPIKey(key)
                            isPresented = false
                        } catch {
                            errorMessage = "Could not save the key to Keychain."
                        }
                    }) {
                        Text("Save")
                            .foregroundColor(.white)
                            .padding(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .background(Color.sbbRed)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(EdgeInsets(top: 0, leading: 16, bottom: 18, trailing: 16))
        }
        .frame(width: 320)
    }
}
