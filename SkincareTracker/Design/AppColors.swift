//
//  AppColors.swift
//  SkincareTracker
//
//  Light and dark mode theme. Colors adapt automatically via asset catalog.
//

import SwiftUI

enum AppColors {

    // MARK: - Surfaces

    /// Main background. Light: light gray. Dark: near black.
    static let background = Color("AppBackground")

    /// Card/surface background. Light: white. Dark: dark gray.
    static let surface = Color("AppSurface")

    // MARK: - Text (contrast-optimized)

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")
    static let textOnDark = Color("TextOnDark")
    /// Text on accent background. Light: white (accent is black). Dark: black (accent is white).
    static let textOnAccent = Color("TextOnAccent")

    // MARK: - Accent / Brand

    static let accent = Color("AppAccent")
    static let accentLight = Color("AccentLight")

    // MARK: - Morning / Night Routines
    // Light mode: soft pastels. Dark mode: richer, darker tones.

    static let morning = Color("Morning")
    static let morningAccent = Color("MorningAccent")
    static let morningCellEmpty = Color("MorningCellEmpty")
    static let night = Color("Night")
    static let nightAccent = Color("NightAccent")
    static let nightCellEmpty = Color("NightCellEmpty")

    // MARK: - Banners

    static let bannerSuccess = Color("BannerSuccess")
    static let bannerWarning = Color("BannerWarning")

    // MARK: - Buttons & Actions

    static let primaryAction = Color("AppAccent")
    static let primaryActionLight = Color("PrimaryActionLight")
    static let secondaryButton = Color("TextTertiary")
    static let putOff = Color("PutOff")
    static let putOffLight = Color("PutOffLight")

    // MARK: - Lists & Rows

    static let rowBackground = Color("RowBackground")
    static let rowSelected = Color("RowSelected")
    static let sectionHeader = Color("TextSecondary")

    // MARK: - Product Cycle Legend (20 palette colors)
    // Do not change the order - defines color order when adding products to the cycle.

    static let productPalette: [Color] = [
        Color(red: 230/255, green: 25/255, blue: 75/255),   // Red #e6194B
        Color(red: 60/255, green: 180/255, blue: 75/255),   // Green #3cb44b
        Color(red: 255/255, green: 225/255, blue: 25/255),   // Yellow #ffe119
        Color(red: 67/255, green: 99/255, blue: 216/255),   // Blue #4363d8
        Color(red: 245/255, green: 130/255, blue: 49/255),  // Orange #f58231
        Color(red: 145/255, green: 30/255, blue: 180/255), // Purple #911eb4
        Color(red: 66/255, green: 212/255, blue: 244/255),  // Cyan #42d4f4
        Color(red: 240/255, green: 50/255, blue: 230/255),  // Magenta #f032e6
        Color(red: 191/255, green: 239/255, blue: 69/255),  // Lime #bfef45
        Color(red: 250/255, green: 190/255, blue: 212/255), // Pink #fabed4
        Color(red: 70/255, green: 153/255, blue: 144/255), // Teal #469990
        Color(red: 220/255, green: 190/255, blue: 255/255), // Lavender #dcbeff
        Color(red: 154/255, green: 99/255, blue: 36/255),   // Brown #9A6324
        Color(red: 255/255, green: 250/255, blue: 200/255), // Beige #fffac8
        Color(red: 128/255, green: 0/255, blue: 0/255),     // Maroon #800000
        Color(red: 170/255, green: 255/255, blue: 195/255), // Mint #aaffc3
        Color(red: 128/255, green: 128/255, blue: 0/255),   // Olive #808000
        Color(red: 255/255, green: 216/255, blue: 177/255), // Apricot #ffd8b1
        Color(red: 0/255, green: 0/255, blue: 117/255),     // Navy #000075
        Color(red: 169/255, green: 169/255, blue: 169/255), // Grey #a9a9a9
    ]
}
