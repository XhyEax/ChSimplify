//
//  ImageTextOverlayView.swift
//  ChSimplify
//
//  以图片为底图，在每行识别文字上叠加绿色框；点击绿框可选中/取消该行。
//

import SwiftUI
import UIKit

struct ImageTextOverlayView: View {
    let image: UIImage
    let lines: [RecognizedLine]
    @Binding var selectedIDs: Set<UUID>
    var showBoxes: Bool = true

    var body: some View {
        // 让容器与图片保持同样的宽高比，图片正好铺满，便于把归一化坐标直接映射到容器尺寸。
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()

                if showBoxes {
                    ForEach(lines) { line in
                    let frame = frame(for: line.boundingBox, in: geo.size)
                    let isSelected = selectedIDs.contains(line.id)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.opacity(isSelected ? 0.28 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color.green, lineWidth: isSelected ? 1.5 : 0.8)
                        )
                        .frame(width: frame.width, height: frame.height)
                        // 用 position（而非 offset）放置，确保渲染与点击命中区域一致。
                        .position(x: frame.midX, y: frame.midY)
                        .onTapGesture { toggle(line.id) }
                    }
                }
            }
        }
        .aspectRatio(image.size, contentMode: .fit)
    }

    /// 把 Vision 归一化边界框（原点左下）映射到视图坐标（原点左上）。
    private func frame(for box: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: box.minX * size.width,
               y: (1 - box.maxY) * size.height,
               width: box.width * size.width,
               height: box.height * size.height)
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}
