import SwiftUI

/// 可拖拽 / 双指缩放的图片裁剪器
/// 输出尺寸按目标宽度等比生成，直接可当小组件背景
struct ImageCropView: View {

    let image: UIImage
    /// 宽 / 高。1.0 = 正方形（通用），2.14 = 中尺寸横幅
    let aspect: CGFloat
    let onCancel: () -> Void
    let onDone: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    private var frameW: CGFloat {
        UIScreen.main.bounds.width - 40
    }
    private var frameH: CGFloat {
        frameW / aspect
    }

    /// 图片按 aspectFill 撑满裁剪框后，再叠用户缩放
    private var displayedSize: CGSize {
        let fill = max(frameW / image.size.width, frameH / image.size.height)
        let s = fill * scale
        return CGSize(width: image.size.width * s, height: image.size.height * s)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { onCancel() }
                    .foregroundStyle(.white)
                Spacer()
                Text("拖动 / 双指缩放")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("完成") { finish() }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Spacer(minLength: 0)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: frameW, height: frameH)
                    .scaleEffect(scale)
                    .offset(offset)

                Rectangle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.2)
                    .frame(width: frameW, height: frameH)
                    .allowsHitTesting(false)

                // 三分线
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.15)).frame(height: 0.5)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.15)).frame(height: 0.5)
                    Spacer()
                }
                .frame(width: frameW, height: frameH)
                .allowsHitTesting(false)

                HStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.15)).frame(width: 0.5)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.15)).frame(width: 0.5)
                    Spacer()
                }
                .frame(width: frameW, height: frameH)
                .allowsHitTesting(false)
            }
            .frame(width: frameW, height: frameH)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(width: baseOffset.width + value.translation.width,
                                        height: baseOffset.height + value.translation.height)
                        clampOffset()
                    }
                    .onEnded { _ in baseOffset = offset }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(baseScale * value, 1), 6)
                        clampOffset()
                    }
                    .onEnded { _ in
                        baseScale = scale
                        baseOffset = offset
                    }
            )

            Spacer(minLength: 0)

            Text(aspect > 1.5 ? "将用于中号小组件（横版）" : "将用于全部尺寸")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - 逻辑

    private func clampOffset() {
        let size = displayedSize
        let maxX = max(0, (size.width - frameW) / 2)
        let maxY = max(0, (size.height - frameH) / 2)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    private func finish() {
        // 目标像素：大尺寸 1146 高已足够覆盖所有家族
        let targetW: CGFloat = 1200
        let outSize = CGSize(width: targetW, height: targetW / aspect)
        let ratio = targetW / frameW
        let size = displayedSize

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let output = UIGraphicsImageRenderer(size: outSize, format: format).image { _ in
            let drawSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            let dx = (outSize.width - drawSize.width) / 2 + offset.width * ratio
            let dy = (outSize.height - drawSize.height) / 2 + offset.height * ratio
            image.draw(in: CGRect(x: dx, y: dy, width: drawSize.width, height: drawSize.height))
        }
        onDone(output)
    }
}
