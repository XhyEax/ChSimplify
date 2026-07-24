//
//  Toast.swift
//  ChSimplify
//
//  底部轻提示：绑定一个可选消息，显示后 3 秒自动消失。用法：.toast($message)
//

import SwiftUI

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.8), in: Capsule())
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation { self.message = nil }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: message)
    }
}
