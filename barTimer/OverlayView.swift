import SwiftUI

struct OverlayView: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        if isVisible {
            ZStack {
                // 高斯模糊背景
                Rectangle()
                    .fill(.ultraThinMaterial) // 使用系统材质
                    .edgesIgnoringSafeArea(.all)
                    .blur(radius: 20)
                
                // 玻璃拟态效果的内容容器
                VStack(spacing: 30) {
                    // 图标
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, options: .repeating)
                    
                    // 文字
                    Text("限定时间结束！")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    // 关闭按钮
                    Button(action: {
                        // 立即关闭，不使用动画避免阻塞
                        isVisible = false
                    }) {
                        Text("知道了")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.blue)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

// 预览
#Preview {
    OverlayView(isVisible: .constant(true))
}
