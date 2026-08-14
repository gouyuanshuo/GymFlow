import SwiftUI
import UIKit

@MainActor
enum WorkoutShareRenderer {
    static let pointSize = CGSize(width: 360, height: 450)
    static let exportScale: CGFloat = 3
    static let pixelSize = CGSize(
        width: pointSize.width * exportScale,
        height: pointSize.height * exportScale
    )

    static func render(
        summary: WorkoutShareSummary,
        background: WorkoutShareBackground
    ) throws -> UIImage {
        let card = WorkoutShareCardView(summary: summary, background: background)
            .frame(width: pointSize.width, height: pointSize.height)

        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(pointSize)
        renderer.scale = exportScale
        renderer.isOpaque = true

        guard let image = renderer.uiImage,
              image.cgImage?.width == Int(pixelSize.width),
              image.cgImage?.height == Int(pixelSize.height) else {
            throw WorkoutShareError.imageRenderFailed
        }
        return image
    }
}
