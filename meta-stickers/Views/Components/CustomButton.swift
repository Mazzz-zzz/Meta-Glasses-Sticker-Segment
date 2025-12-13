//
//  CustomButton.swift
//  meta-stickers
//

import SwiftUI

struct CustomButton: View {
    let title: String
    let style: ButtonStyle
    let isDisabled: Bool
    let action: () -> Void

    init(title: String, style: ButtonStyle = .primary, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }

    enum ButtonStyle {
        case primary, destructive

        var backgroundColor: Color {
            switch self {
            case .primary:
                return .appPrimary
            case .destructive:
                return .destructiveBackground
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary:
                return .white
            case .destructive:
                return .destructiveForeground
            }
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(style.foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(style.backgroundColor)
                .cornerRadius(30)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}
