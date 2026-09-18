import SwiftUI

/// Presents `SpoofSession.lastError` from inside a sheet.
///
/// The root view already carries this alert, but an alert attached to a view that a
/// sheet covers cannot appear while that sheet is up — so failures raised from the
/// Routes or Settings sheets (start a GPX route, build a road route, import/export)
/// were recorded and never shown, which looked like the button did nothing.
struct SessionErrorAlert: ViewModifier {
    @EnvironmentObject private var session: SpoofSession

    func body(content: Content) -> some View {
        content.alert("Locus", isPresented: Binding(
            get: { session.lastError != nil },
            set: { if !$0 { session.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { session.lastError = nil }
        } message: {
            Text(session.lastError ?? "")
        }
    }
}

extension View {
    func sessionErrorAlert() -> some View {
        modifier(SessionErrorAlert())
    }
}
