import SwiftUI
import UIKit

enum EsseLineaLayout {
    static let screenMargin: CGFloat = 4
    static let contentSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 22
}

enum EsseLineaTheme {
    // Dynamic palette: follows the iPhone's system Light/Dark appearance automatically.
    static let uiBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    }

    static let uiSurface = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.07, alpha: 1)
            : UIColor(white: 0.96, alpha: 1)
    }

    static let uiSurfaceElevated = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.11, alpha: 1)
            : UIColor(white: 0.92, alpha: 1)
    }

    static let uiTextPrimary = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    }

    static let uiTextSecondary = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.62, alpha: 1)
            : UIColor(white: 0.38, alpha: 1)
    }

    static let uiDivider = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.12)
            : UIColor.black.withAlphaComponent(0.10)
    }

    static let uiAccent = UIColor(red: 10 / 255, green: 132 / 255, blue: 255 / 255, alpha: 1)

    // SwiftUI equivalents.
    static let background = Color(uiColor: uiBackground)
    static let surface = Color(uiColor: uiSurface)
    static let surfaceElevated = Color(uiColor: uiSurfaceElevated)
    static let accent = Color(uiColor: uiAccent)
    static let textPrimary = Color(uiColor: uiTextPrimary)
    static let textSecondary = Color(uiColor: uiTextSecondary)
    static let divider = Color(uiColor: uiDivider)
}

enum AppearanceManager {
    static func setupGlobalAppearance() {
        UIWindow.appearance().backgroundColor = EsseLineaTheme.uiBackground
        UIScrollView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear

        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().backgroundColor = .clear
        UITableViewHeaderFooterView.appearance().tintColor = .clear

        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = EsseLineaTheme.uiAccent

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = EsseLineaTheme.uiBackground
        navigationAppearance.shadowColor = .clear
        navigationAppearance.titleTextAttributes = [.foregroundColor: EsseLineaTheme.uiTextPrimary]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: EsseLineaTheme.uiTextPrimary]

        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().tintColor = EsseLineaTheme.uiAccent

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = EsseLineaTheme.uiBackground
        tabAppearance.shadowColor = EsseLineaTheme.uiDivider

        let itemAppearances = [
            tabAppearance.stackedLayoutAppearance,
            tabAppearance.inlineLayoutAppearance,
            tabAppearance.compactInlineLayoutAppearance
        ]

        itemAppearances.forEach { itemAppearance in
            itemAppearance.normal.iconColor = EsseLineaTheme.uiTextSecondary
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: EsseLineaTheme.uiTextSecondary]
            itemAppearance.selected.iconColor = EsseLineaTheme.uiAccent
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: EsseLineaTheme.uiAccent]
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = EsseLineaTheme.uiAccent
    }
}
