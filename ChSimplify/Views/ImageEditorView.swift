//
//  ImageEditorView.swift
//  ChSimplify
//
//  图片编辑页：裁剪（拖动四角）、90° 旋转，以及底部刻度尺微调任意角度旋转。
//

import SwiftUI
import UIKit

/// 进入编辑页所需的数据。
struct EditPayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ImageEditorView: View {
    let original: UIImage
    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var working: UIImage
    @State private var imageRect: CGRect = .zero        // 图片在编辑区内的 aspect-fit 矩形（B）
    @State private var cropRect: CGRect = .zero
    @State private var activeHandle: Handle?
    @State private var cropAtStart: CGRect = .zero
    @State private var fineAngle: Double = 0            // 微调旋转角度（度）
    @State private var areaSize: CGSize = .zero

    private let handleHitRadius: CGFloat = 36
    private let minCropSize: CGFloat = 60

    init(original: UIImage,
         onDone: @escaping (UIImage) -> Void,
         onCancel: @escaping () -> Void) {
        self.original = original
        self.onDone = onDone
        self.onCancel = onCancel
        _working = State(initialValue: original.normalizedUp())
    }

    enum Handle { case topLeft, topRight, bottomLeft, bottomRight, move }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            editorArea
            bottomBar
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - 编辑区

    private var editorArea: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: working)
                    .resizable()
                    .scaledToFit()
                    .frame(width: max(1, geo.size.width - edgeInset * 2),
                           height: max(1, geo.size.height - edgeInset * 2))
                    .scaleEffect(coverScale)
                    .rotationEffect(.degrees(fineAngle))

                if cropRect.width > 1 {
                    Path { p in
                        p.addRect(CGRect(origin: .zero, size: geo.size))
                        p.addRect(cropRect)
                    }
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

                    grid
                    Path { $0.addRect(cropRect) }
                        .stroke(Color.white, lineWidth: 1.5)
                    handles
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(cropDrag)
            .onAppear { layout(in: geo.size, resetCrop: true) }
            .onChange(of: geo.size) { newSize in
                layout(in: newSize, resetCrop: true)
            }
        }
    }

    private var grid: some View {
        Path { p in
            for i in 1...2 {
                let x = cropRect.minX + cropRect.width * CGFloat(i) / 3
                p.move(to: CGPoint(x: x, y: cropRect.minY))
                p.addLine(to: CGPoint(x: x, y: cropRect.maxY))
                let y = cropRect.minY + cropRect.height * CGFloat(i) / 3
                p.move(to: CGPoint(x: cropRect.minX, y: y))
                p.addLine(to: CGPoint(x: cropRect.maxX, y: y))
            }
        }
        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
    }

    private var handles: some View {
        ForEach(Array(corners(of: cropRect).enumerated()), id: \.offset) { _, pt in
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .position(pt)
        }
    }

    private func corners(of r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.minY),
         CGPoint(x: r.maxX, y: r.minY),
         CGPoint(x: r.minX, y: r.maxY),
         CGPoint(x: r.maxX, y: r.maxY)]
    }

    /// 旋转后把图片放大以铺满裁剪框（避免出现黑边），返回所需的最小缩放系数。
    private var coverScale: CGFloat {
        guard cropRect.width > 1, imageRect.width > 1 else { return 1 }
        let theta = CGFloat(fineAngle) * .pi / 180
        let bc = CGPoint(x: imageRect.midX, y: imageRect.midY)
        let halfW = imageRect.width / 2, halfH = imageRect.height / 2
        var k: CGFloat = 1
        for q in corners(of: cropRect) {
            let dx = q.x - bc.x, dy = q.y - bc.y
            let ux = cos(theta) * dx + sin(theta) * dy
            let uy = -sin(theta) * dx + cos(theta) * dy
            k = max(k, abs(ux) / halfW)
            k = max(k, abs(uy) / halfH)
        }
        return k
    }

    // MARK: - 顶部 / 底部栏

    private var topBar: some View {
        HStack {
            Button("取消") { onCancel() }
                .foregroundStyle(.white)
            Spacer()
            Text("编辑")
                .font(.headline).foregroundStyle(.white)
            Spacer()
            Button("完成") { finish() }
                .font(.headline.bold())
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("\(fineAngle, specifier: "%.0f")°")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
                RotationRuler(angle: $fineAngle)
            }

            HStack(spacing: 28) {
                toolButton("向左旋转", "rotate.left") { rotate(clockwise: false) }
                toolButton("向右旋转", "rotate.right") { rotate(clockwise: true) }
                toolButton("重置", "arrow.counterclockwise") { reset() }
            }
        }
        .padding(.vertical, 14)
    }

    private func toolButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption)
            }
            .foregroundStyle(.white)
        }
    }

    // MARK: - 手势

    private var cropDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeHandle == nil {
                    activeHandle = handle(at: value.startLocation)
                    cropAtStart = cropRect
                }
                guard let handle = activeHandle else { return }
                let tx = value.location.x - value.startLocation.x
                let ty = value.location.y - value.startLocation.y
                cropRect = newCrop(handle, tx, ty)
            }
            .onEnded { _ in
                let resized = activeHandle != nil && activeHandle != .move
                activeHandle = nil
                if resized { zoomToCrop() }
            }
    }

    /// 裁剪框缩小后松手：把当前裁剪（含旋转）烘焙进图片，并放大铺满编辑区。
    private func zoomToCrop() {
        guard imageRect.width > 1, cropRect.width > 1 else { return }
        let f = min(areaSize.width / cropRect.width, areaSize.height / cropRect.height)
        guard f > 1.01 else { return }      // 裁剪框接近整图时不缩放
        let cropped = working.croppedRotated(viewRect: cropRect,
                                             imageRect: imageRect,
                                             angleDegrees: fineAngle,
                                             scale: coverScale)
        working = cropped
        fineAngle = 0
        withAnimation(.easeInOut(duration: 0.25)) {
            layout(in: areaSize, resetCrop: true)
        }
    }

    private func handle(at p: CGPoint) -> Handle? {
        let c = corners(of: cropRect)
        let names: [Handle] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        for (pt, name) in zip(c, names) where hypot(p.x - pt.x, p.y - pt.y) < handleHitRadius {
            return name
        }
        return cropRect.contains(p) ? .move : nil
    }

    private func newCrop(_ h: Handle, _ tx: CGFloat, _ ty: CGFloat) -> CGRect {
        switch h {
        case .move:
            var r = cropAtStart.offsetBy(dx: tx, dy: ty)
            r.origin.x = min(max(r.origin.x, imageRect.minX), imageRect.maxX - r.width)
            r.origin.y = min(max(r.origin.y, imageRect.minY), imageRect.maxY - r.height)
            return r
        case .topLeft:
            let nx = clampVal(cropAtStart.minX + tx, imageRect.minX, cropAtStart.maxX - minCropSize)
            let ny = clampVal(cropAtStart.minY + ty, imageRect.minY, cropAtStart.maxY - minCropSize)
            return CGRect(x: nx, y: ny, width: cropAtStart.maxX - nx, height: cropAtStart.maxY - ny)
        case .topRight:
            let nMaxX = clampVal(cropAtStart.maxX + tx, cropAtStart.minX + minCropSize, imageRect.maxX)
            let ny = clampVal(cropAtStart.minY + ty, imageRect.minY, cropAtStart.maxY - minCropSize)
            return CGRect(x: cropAtStart.minX, y: ny, width: nMaxX - cropAtStart.minX, height: cropAtStart.maxY - ny)
        case .bottomLeft:
            let nx = clampVal(cropAtStart.minX + tx, imageRect.minX, cropAtStart.maxX - minCropSize)
            let nMaxY = clampVal(cropAtStart.maxY + ty, cropAtStart.minY + minCropSize, imageRect.maxY)
            return CGRect(x: nx, y: cropAtStart.minY, width: cropAtStart.maxX - nx, height: nMaxY - cropAtStart.minY)
        case .bottomRight:
            let nMaxX = clampVal(cropAtStart.maxX + tx, cropAtStart.minX + minCropSize, imageRect.maxX)
            let nMaxY = clampVal(cropAtStart.maxY + ty, cropAtStart.minY + minCropSize, imageRect.maxY)
            return CGRect(x: cropAtStart.minX, y: cropAtStart.minY, width: nMaxX - cropAtStart.minX, height: nMaxY - cropAtStart.minY)
        }
    }

    private func clampVal(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), max(lo, hi))
    }

    // MARK: - 布局 / 操作

    private let edgeInset: CGFloat = 24     // 图片四周留白，避免裁剪框贴屏幕边缘

    private func layout(in size: CGSize, resetCrop: Bool) {
        guard size.width > 0, size.height > 0 else { return }
        areaSize = size
        let inner = CGSize(width: max(1, size.width - edgeInset * 2),
                           height: max(1, size.height - edgeInset * 2))
        imageRect = Self.fitRect(working.size, in: inner).offsetBy(dx: edgeInset, dy: edgeInset)
        if resetCrop || cropRect.width < 1 {
            cropRect = imageRect
        }
    }

    private func rotate(clockwise: Bool) {
        working = working.rotated90(clockwise: clockwise)
        fineAngle = 0
        layout(in: areaSize, resetCrop: true)
    }

    private func reset() {
        working = original.normalizedUp()
        fineAngle = 0
        layout(in: areaSize, resetCrop: true)
    }

    private func finish() {
        let result = working.croppedRotated(viewRect: cropRect,
                                            imageRect: imageRect,
                                            angleDegrees: fineAngle,
                                            scale: coverScale)
        onDone(result)
    }

    private static func fitRect(_ imgSize: CGSize, in size: CGSize) -> CGRect {
        guard imgSize.width > 0, imgSize.height > 0 else { return .zero }
        let scale = min(size.width / imgSize.width, size.height / imgSize.height)
        let w = imgSize.width * scale, h = imgSize.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }
}

/// 底部刻度尺：拖动微调旋转角度（-45°…45°）。
private struct RotationRuler: View {
    @Binding var angle: Double
    @State private var dragStart: Double?

    private let range: ClosedRange<Double> = -45...45
    private let pxPerDeg: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            Canvas { ctx, size in
                let h = size.height
                var d = ceil(range.lowerBound)
                while d <= range.upperBound {
                    let x = mid + (CGFloat(d) - CGFloat(angle)) * pxPerDeg
                    if x >= 0, x <= size.width {
                        let major = Int(d) % 5 == 0
                        let tickH: CGFloat = major ? 16 : 9
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: h / 2 - tickH / 2))
                        path.addLine(to: CGPoint(x: x, y: h / 2 + tickH / 2))
                        ctx.stroke(path,
                                   with: .color(.white.opacity(major ? 0.9 : 0.45)),
                                   lineWidth: major ? 1.5 : 1)
                    }
                    d += 1
                }
                var pointer = Path()
                pointer.move(to: CGPoint(x: mid, y: 2))
                pointer.addLine(to: CGPoint(x: mid, y: h - 2))
                ctx.stroke(pointer, with: .color(.green), lineWidth: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStart == nil { dragStart = angle }
                        // 向左拖动增大角度（与刻度移动方向一致）。
                        let delta = Double(-value.translation.width / pxPerDeg)
                        angle = min(max((dragStart ?? 0) + delta, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in dragStart = nil }
            )
        }
        .frame(height: 40)
    }
}

private extension UIImage {
    /// 把方向烘焙为 .up，使 cgImage 与显示一致，便于裁剪计算。
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// 顺/逆时针旋转 90°，返回方向为 .up 的新图。
    func rotated90(clockwise: Bool) -> UIImage {
        let newSize = CGSize(width: size.height, height: size.width)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            c.rotate(by: clockwise ? .pi / 2 : -.pi / 2)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    /// 按显示坐标系中的裁剪框 + 微调旋转 + 铺满缩放，渲染最终结果图。
    /// 变换与屏幕显示一致：图片填充 B，绕 B 中心缩放 k、旋转 θ，再截取裁剪框 C。
    func croppedRotated(viewRect c: CGRect, imageRect b: CGRect,
                        angleDegrees deg: Double, scale k: CGFloat) -> UIImage {
        guard let cg = cgImage, b.width > 0, c.width > 0 else { return self }
        let s = CGFloat(cg.width) / b.width                 // 视图点 → 像素
        let outSize = CGSize(width: max(1, c.width * s), height: max(1, c.height * s))
        let theta = CGFloat(deg) * .pi / 180
        let bc = CGPoint(x: b.midX, y: b.midY)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: outSize, format: format)
        return renderer.image { rc in
            let ctx = rc.cgContext
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(CGRect(origin: .zero, size: outSize))

            ctx.translateBy(x: -c.minX * s, y: -c.minY * s)
            ctx.translateBy(x: bc.x * s, y: bc.y * s)
            ctx.rotate(by: theta)
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -bc.x * s, y: -bc.y * s)
            draw(in: CGRect(x: b.minX * s, y: b.minY * s, width: b.width * s, height: b.height * s))
        }
    }
}
