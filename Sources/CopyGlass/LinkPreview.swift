import SwiftUI
import LinkPresentation

@MainActor final class LinkPreviewModel: ObservableObject {
    @Published var title: String?
    @Published var image: NSImage?
    @Published var loading = true
    private static let cache = NSCache<NSURL, LPLinkMetadata>()
    func load(_ url: URL) async {
        defer { loading = false }
        let metadata: LPLinkMetadata
        if let cached = Self.cache.object(forKey: url as NSURL) { metadata = cached }
        else {
            let provider = LPMetadataProvider()
            provider.timeout = 12
            do {
                metadata = try await withTaskCancellationHandler(operation: {
                    try await provider.startFetchingMetadata(for: url)
                }, onCancel: { provider.cancel() })
                guard !Task.isCancelled else { return }
                Self.cache.countLimit = 100
                Self.cache.setObject(metadata, forKey: url as NSURL)
            } catch { return }
        }
        guard !Task.isCancelled else { return }
        title = metadata.title
        guard let provider = metadata.imageProvider ?? metadata.iconProvider,
              provider.canLoadObject(ofClass: NSImage.self) else { return }
        let loaded: NSImage? = await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSImage.self) { object, _ in continuation.resume(returning: object as? NSImage) }
        }
        guard !Task.isCancelled else { return }
        image = loaded
    }
}

struct LinkPreview: View {
    let url: URL
    @EnvironmentObject private var localization: AppLocalization
    @StateObject private var model = LinkPreviewModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(.quaternary)
                    if let image = model.image {
                        Image(nsImage: image).resizable().scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if model.loading { ProgressView().controlSize(.small) }
                    else { Image(systemName: "link").font(.title2).foregroundStyle(.secondary) }
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }.frame(height: 110).clipShape(RoundedRectangle(cornerRadius: 10))
            Text(model.title ?? url.host ?? localization.text("Bağlantı")).font(.subheadline.weight(.medium)).lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .topLeading)
            Text(url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                .frame(height: 15, alignment: .top)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .task(id: url) { await model.load(url) }
    }
}

struct ImagePreview: View {
    let image: NSImage
    let title: String
    var thumbnailHeight: CGFloat = 130
    let copy: () -> Bool
    @EnvironmentObject private var localization: AppLocalization
    @State private var showPreview = false
    private var previewWidth: CGFloat { min(560, (NSScreen.main?.visibleFrame.width ?? 900) - 80) }
    private var previewImageHeight: CGFloat { min(380, (NSScreen.main?.visibleFrame.height ?? 700) - 220) }
    var body: some View {
        GeometryReader { geometry in
            Image(nsImage: image).resizable().scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture { showPreview = true }
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { showPreview = true }
                .popover(isPresented: $showPreview, arrowEdge: .trailing) {
                    VStack(spacing: 0) {
                        HStack {
                            Text(title).font(.headline).lineLimit(1)
                            Spacer()
                            Button { showPreview = false } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).help(localization.text("Önizlemeyi kapat"))
                                .accessibilityLabel(localization.text("Önizlemeyi kapat"))
                        }.padding(18)
                        Image(nsImage: image).resizable().scaledToFit()
                            .frame(width: previewWidth - 36, height: previewImageHeight)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 18).padding(.bottom, 18)
                        Divider()
                        HStack(spacing: 16) {
                            Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength: 12)
                            CopyFeedbackButton(prominent: true, action: copy)

                        }.padding(18).frame(height: 80)
                            .background(.regularMaterial)
                    }.frame(width: previewWidth)
                        .fixedSize(horizontal: false, vertical: true)

                }
        }.frame(height: thumbnailHeight)
    }
}
