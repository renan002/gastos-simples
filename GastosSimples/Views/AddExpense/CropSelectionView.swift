import SwiftUI

/// Full-screen crop selector shown after picking a screenshot.
/// User drags corner handles to define the region passed to OCR.
struct CropSelectionView: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void  // called with cropped image
    let onSkip: () -> Void            // use full image as-is

    @State private var imageRect: CGRect = .zero
    @State private var selection: CGRect = .zero
    @State private var dragStartSelection: CGRect? = nil

    private let handleRadius: CGFloat = 13
    private let minSelectionSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let fitted = fittedRect(imageSize: image.size, in: geo.size)

                ZStack {
                    Color.black

                    Image(uiImage: normalised(image))
                        .resizable()
                        .scaledToFit()
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: fitted.midX, y: fitted.midY)

                    if selection != .zero {
                        DimmingMask(selection: selection)

                        SelectionBorderView(rect: selection)

                        // Interior drag — moves the whole rectangle
                        Color.clear
                            .frame(
                                width:  max(0, selection.width  - handleRadius * 4),
                                height: max(0, selection.height - handleRadius * 4)
                            )
                            .position(x: selection.midX, y: selection.midY)
                            .contentShape(Rectangle())
                            .gesture(moveGesture())

                        // Corner handles
                        ForEach(CropCorner.allCases, id: \.self) { corner in
                            CropHandle(radius: handleRadius)
                                .position(corner.position(in: selection))
                                .gesture(resizeGesture(for: corner))
                        }
                    }
                }
                .onAppear {
                    imageRect = fitted
                    selection = CGRect(
                        x: fitted.minX + fitted.width  * 0.10,
                        y: fitted.minY + fitted.height * 0.10,
                        width:  fitted.width  * 0.80,
                        height: fitted.height * 0.80
                    )
                }
            }

            // Bottom action bar
            HStack(spacing: 16) {
                Button("Usar Imagem Completa") { onSkip() }
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()

                Button {
                    let norm = normalisedSelection(selection, within: imageRect)
                    onConfirm(crop(normalised(image), to: norm))
                } label: {
                    Label("Escanear Área", systemImage: "viewfinder.circle.fill")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(white: 0.08))
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    // MARK: - Gestures

    private func moveGesture() -> some Gesture {
        DragGesture()
            .onChanged { val in
                if dragStartSelection == nil { dragStartSelection = selection }
                guard let start = dragStartSelection else { return }
                var r = start.offsetBy(dx: val.translation.width, dy: val.translation.height)
                r.origin.x = max(imageRect.minX, min(imageRect.maxX - r.width,  r.origin.x))
                r.origin.y = max(imageRect.minY, min(imageRect.maxY - r.height, r.origin.y))
                selection = r
            }
            .onEnded { _ in dragStartSelection = nil }
    }

    private func resizeGesture(for corner: CropCorner) -> some Gesture {
        DragGesture()
            .onChanged { val in
                if dragStartSelection == nil { dragStartSelection = selection }
                guard let start = dragStartSelection else { return }
                selection = corner.updated(
                    start,
                    translation: val.translation,
                    within: imageRect,
                    minSize: minSelectionSize
                )
            }
            .onEnded { _ in dragStartSelection = nil }
    }

    // MARK: - Geometry helpers

    private func fittedRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        let iA = imageSize.width / imageSize.height
        let cA = containerSize.width / containerSize.height
        if iA < cA {
            let h = containerSize.height
            let w = h * iA
            return CGRect(x: (containerSize.width - w) / 2, y: 0, width: w, height: h)
        } else {
            let w = containerSize.width
            let h = w / iA
            return CGRect(x: 0, y: (containerSize.height - h) / 2, width: w, height: h)
        }
    }

    private func normalisedSelection(_ rect: CGRect, within imageRect: CGRect) -> CGRect {
        CGRect(
            x: (rect.minX - imageRect.minX) / imageRect.width,
            y: (rect.minY - imageRect.minY) / imageRect.height,
            width:  rect.width  / imageRect.width,
            height: rect.height / imageRect.height
        )
    }

    private func crop(_ image: UIImage, to norm: CGRect) -> UIImage {
        let w = image.size.width, h = image.size.height
        let pixelRect = CGRect(
            x: norm.minX * w, y: norm.minY * h,
            width: norm.width * w, height: norm.height * h
        )
        guard let cg = image.cgImage?.cropping(to: pixelRect) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }

    /// Redraws the image so cgImage pixel data always matches `.up` orientation.
    private func normalised(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(at: .zero) }
    }
}

// MARK: - Corner enum

private enum CropCorner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:     CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:    CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:  CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    func updated(
        _ rect: CGRect,
        translation: CGSize,
        within bounds: CGRect,
        minSize: CGFloat
    ) -> CGRect {
        var minX = rect.minX, minY = rect.minY
        var maxX = rect.maxX, maxY = rect.maxY

        switch self {
        case .topLeft:
            minX = max(bounds.minX, min(maxX - minSize, minX + translation.width))
            minY = max(bounds.minY, min(maxY - minSize, minY + translation.height))
        case .topRight:
            maxX = max(minX + minSize, min(bounds.maxX, maxX + translation.width))
            minY = max(bounds.minY, min(maxY - minSize, minY + translation.height))
        case .bottomLeft:
            minX = max(bounds.minX, min(maxX - minSize, minX + translation.width))
            maxY = max(minY + minSize, min(bounds.maxY, maxY + translation.height))
        case .bottomRight:
            maxX = max(minX + minSize, min(bounds.maxX, maxX + translation.width))
            maxY = max(minY + minSize, min(bounds.maxY, maxY + translation.height))
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - Corner handle shape

private struct CropHandle: View {
    let radius: CGFloat

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }
}

// MARK: - Dimming overlay (darkens outside the selection rect)

private struct DimmingMask: View {
    let selection: CGRect

    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                path.addRect(selection)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Selection border with rule-of-thirds grid

private struct SelectionBorderView: View {
    let rect: CGRect

    var body: some View {
        Canvas { ctx, _ in
            // Border
            ctx.stroke(
                Path(rect),
                with: .color(.white.opacity(0.9)),
                lineWidth: 1.5
            )

            // Rule-of-thirds grid
            let thirdW = rect.width / 3
            let thirdH = rect.height / 3
            for i in 1...2 {
                let vPath = Path { p in
                    let x = rect.minX + thirdW * CGFloat(i)
                    p.move(to:    CGPoint(x: x, y: rect.minY))
                    p.addLine(to: CGPoint(x: x, y: rect.maxY))
                }
                let hPath = Path { p in
                    let y = rect.minY + thirdH * CGFloat(i)
                    p.move(to:    CGPoint(x: rect.minX, y: y))
                    p.addLine(to: CGPoint(x: rect.maxX, y: y))
                }
                ctx.stroke(vPath, with: .color(.white.opacity(0.25)), lineWidth: 0.5)
                ctx.stroke(hPath, with: .color(.white.opacity(0.25)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}
