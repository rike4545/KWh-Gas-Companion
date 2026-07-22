//
//  ActivityView.swift
//  KWh Gas Companion
//
//

// ActivityView.swift
// KWh Gas Companion
//
// SwiftUI wrapper for UIActivityViewController (Share Sheet)

import SwiftUI

#if canImport(UIKit)
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    var subject: String? = nil
    var completion: UIActivityViewController.CompletionWithItemsHandler? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems,
                                                  applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        if let subject {
            // Commonly respected by Mail
            controller.setValue(subject, forKey: "subject")
        }
        controller.completionWithItemsHandler = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // nothing to update live
    }
}

#else

// Fallback for non-UIKit platforms so the project still compiles.
struct ActivityView: View {
    var activityItems: [Any]
    var body: some View {
        Text("Sharing is not available on this platform.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding()
    }
}
#endif
