import SwiftUI
import UIKit

enum AppTheme {
    enum Colors {
        static var bgPrimary: Color { dynamic(light: UIColor(red: 245 / 255, green: 250 / 255, blue: 1.0, alpha: 1), dark: UIColor(red: 7 / 255, green: 9 / 255, blue: 13 / 255, alpha: 1)) }
        static var bgSecondary: Color { dynamic(light: UIColor(red: 234 / 255, green: 242 / 255, blue: 1.0, alpha: 1), dark: UIColor(red: 13 / 255, green: 17 / 255, blue: 24 / 255, alpha: 1)) }
        static var cardBase: Color { dynamic(light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.62), dark: UIColor(red: 21 / 255, green: 28 / 255, blue: 38 / 255, alpha: 0.72)) }
        static var cardGlassTint: Color { dynamic(light: UIColor(red: 219 / 255, green: 235 / 255, blue: 1.0, alpha: 0.35), dark: UIColor(red: 46 / 255, green: 76 / 255, blue: 122 / 255, alpha: 0.22)) }
        static var textPrimary: Color { dynamic(light: UIColor(red: 16 / 255, green: 30 / 255, blue: 53 / 255, alpha: 1), dark: UIColor(red: 234 / 255, green: 242 / 255, blue: 1.0, alpha: 1)) }
        static var textSecondary: Color { dynamic(light: UIColor(red: 70 / 255, green: 94 / 255, blue: 128 / 255, alpha: 1), dark: UIColor(red: 147 / 255, green: 164 / 255, blue: 191 / 255, alpha: 1)) }
        static var neonPrimary: Color { dynamic(light: UIColor(red: 0 / 255, green: 172 / 255, blue: 110 / 255, alpha: 1), dark: UIColor(red: 57 / 255, green: 1.0, blue: 136 / 255, alpha: 1)) }
        static var neonSecondary: Color { dynamic(light: UIColor(red: 0 / 255, green: 149 / 255, blue: 255 / 255, alpha: 1), dark: UIColor(red: 77 / 255, green: 216 / 255, blue: 1.0, alpha: 1)) }
        static var danger: Color { dynamic(light: UIColor(red: 224 / 255, green: 62 / 255, blue: 88 / 255, alpha: 1), dark: UIColor(red: 1.0, green: 77 / 255, blue: 109 / 255, alpha: 1)) }
        static var cardStroke: Color { dynamic(light: UIColor(red: 127 / 255, green: 159 / 255, blue: 199 / 255, alpha: 0.32), dark: UIColor(red: 133 / 255, green: 155 / 255, blue: 189 / 255, alpha: 0.22)) }

        private static func dynamic(light: UIColor, dark: UIColor) -> Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? dark : light
            })
        }
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Typography {
        static let hero = Font.system(size: 32, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .bold, design: .rounded)
        static let cardTitle = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 14, weight: .regular, design: .rounded)
        static let monoNumber = Font.system(size: 15, weight: .bold, design: .rounded).monospacedDigit()
    }

    enum Motion {
        static let spring = Animation.spring(response: 0.32, dampingFraction: 0.62)
        static let pop = Animation.spring(response: 0.26, dampingFraction: 0.58)
        static let cardIn = Animation.spring(response: 0.38, dampingFraction: 0.72)
    }
}

extension View {
    func appBackground() -> some View {
        background(
            ZStack {
                LinearGradient(
                    colors: [AppTheme.Colors.bgPrimary, AppTheme.Colors.bgSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(AppTheme.Colors.neonPrimary.opacity(0.14))
                    .frame(width: 320, height: 320)
                    .blur(radius: 42)
                    .offset(x: -140, y: -280)

                Circle()
                    .fill(AppTheme.Colors.neonSecondary.opacity(0.16))
                    .frame(width: 260, height: 260)
                    .blur(radius: 36)
                    .offset(x: 170, y: 260)
            }
            .ignoresSafeArea()
        )
    }
}
