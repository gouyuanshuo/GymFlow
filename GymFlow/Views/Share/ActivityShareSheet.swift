import LinkPresentation
import SwiftUI
import UIKit

struct ActivityShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let workoutName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [WorkoutShareActivityItemSource(image: image, workoutName: workoutName)],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private final class WorkoutShareActivityItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let workoutName: String

    init(image: UIImage, workoutName: String) {
        self.image = image
        self.workoutName = workoutName
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "\(workoutName) • GymFlow"
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}
