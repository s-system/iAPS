import SwiftUI
import UIKit

enum EsseLineaTheme {
    // Core palette
    static let background = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let surface = Color(red: 21 / 255, green: 21 / 255, blue: 21 / 255)
    static let surfaceElevated = Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255)
    static let accent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let textPrimary = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)
    static let textSecondary = Color(red: 159 / 255, green: 159 / 255, blue: 168 / 255)
    static let divider = Color.white.opacity(0.10)

    // UIKit equivalents for global appearance APIs
    static let uiBackground = UIColor(red: 10 / 255, green: 10 / 255, blue: 10 / 255, alpha: 1)
    static let uiSurface = UIColor(red: 21 / 255, green: 21 / 255, blue: 21 / 255, alpha: 1)
    static let uiAccent = UIColor(red: 10 / 255, green: 132 / 255, blue: 255 / 255, alpha: 1)
    static let uiTextPrimary = UIColor(red: 245 / 255, green: 245 / 255, blue: 247 / 255, alpha: 1)
    static let uiTextSecondary = UIColor(red: 159 / 255, green: 159 / 255, blue: 168 / 255, alpha: 1)
}

enum AppearanceManager {
    static func setupGlobalAppearance() {
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
        tabAppearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

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
