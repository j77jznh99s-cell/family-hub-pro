import FamilyHubCore
import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Theme {
    var accent: Color { Color(hex: colors.0) }
    var gradient: LinearGradient {
        LinearGradient(colors: [Color(hex: colors.0), Color(hex: colors.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Urgency {
    var color: Color {
        switch self {
        case .overdue: return .red
        case .due: return .orange
        case .dueSoon: return .blue
        case .upToDate: return .green
        }
    }
}

/// Decoded photos, kept in memory so scrolling lists never touch the disk twice.
@MainActor
enum ImageCache {
    private static let cache = NSCache<NSURL, UIImage>()

    static func image(at url: URL) -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    static func invalidate(_ url: URL) { cache.removeObject(forKey: url as NSURL) }

    /// Shrink and re-encode so photos stay small enough for the widget (which has a tight memory limit).
    nonisolated static func jpeg(from data: Data, maxSide: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}

/// A person's photo, or their initials on a theme gradient.
struct Avatar: View {
    @Environment(AppModel.self) private var model
    let person: Person
    var size: CGFloat = 44

    var body: some View {
        let _ = model.photoVersion // re-render when photos change
        Group {
            if let image = model.photo(for: person.id) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(model.theme.gradient)
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: String {
        let parts = person.name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

/// Your background photo (dimmed so text stays readable), or a soft theme wash.
struct AppBackground: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let _ = model.photoVersion
        GeometryReader { geo in
            if let image = model.backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.35))
            } else {
                model.theme.gradient.opacity(0.12)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .ignoresSafeArea()
    }
}

/// A card surface that stays legible on top of a photo.
struct CardBackground: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(model.hasBackground ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
        }
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}
