import SwiftUI

struct CurrentGlucoseView: View {
    @Binding var recentGlucose: BloodGlucose?
    @Binding var delta: Int?
    @Binding var units: GlucoseUnits
    @Binding var alarm: GlucoseAlarm?
    @Binding var lowGlucose: Decimal
    @Binding var highGlucose: Decimal
    @Binding var alwaysUseColors: Bool
    @Binding var displayDelta: Bool
    @Binding var scrolling: Bool
    @Binding var displaySAGE: Bool
    @Binding var displayExpiration: Bool
    @Binding var sensordays: Double
    @Binding var timerDate: Date

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) private var fontSize

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            formatter.roundingMode = .halfUp
        }
        return formatter
    }

    private var manualGlucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            formatter.roundingMode = .ceiling
        }
        return formatter
    }

    private var deltaFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if units == .mmolL {
            formatter.decimalSeparator = "."
        }
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter
    }

    private var timeAgoFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.negativePrefix = ""
        return formatter
    }

    private var remainingTimeFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        return formatter
    }

    private var remainingTimeFormatterDays: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day]
        formatter.unitsStyle = .abbreviated
        return formatter
    }

    var body: some View {
        Group {
            if scrolling {
                compactGlucoseView
            } else {
                modernGlucoseCard
            }
        }
        .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.xLarge)
    }

    private var modernGlucoseCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(EsseLineaTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(EsseLineaTheme.divider, lineWidth: 1)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 14, y: 6)

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GLUCOSE")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(EsseLineaTheme.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(glucoseString)
                            .font(.system(size: 58, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.72)
                            .foregroundStyle(glucoseColor)
                            .contentTransition(.numericText())

                        Image(systemName: trendSymbol)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(glucoseColor)
                    }

                    Text(units.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(EsseLineaTheme.textSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 12) {
                    metricPill(
                        title: NSLocalizedString("Change", comment: "Glucose delta"),
                        value: deltaString,
                        systemImage: "waveform.path.ecg"
                    )

                    metricPill(
                        title: NSLocalizedString("Updated", comment: "Last glucose update"),
                        value: ageString,
                        systemImage: "clock"
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            if displayExpiration || displaySAGE {
                sageBadge
                    .padding(14)
            }
        }
        .frame(maxWidth: 470, minHeight: 150, maxHeight: 170)
        .padding(.horizontal, 18)
    }

    private var compactGlucoseView: some View {
        HStack(spacing: 10) {
            Text(glucoseString)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(glucoseColor)
                .contentTransition(.numericText())

            Image(systemName: trendSymbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(glucoseColor)

            Text(units.rawValue)
                .font(.caption)
                .foregroundStyle(EsseLineaTheme.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(EsseLineaTheme.surface)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(EsseLineaTheme.divider, lineWidth: 1)
                }
        )
    }

    private func metricPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EsseLineaTheme.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(EsseLineaTheme.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EsseLineaTheme.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(EsseLineaTheme.surfaceElevated)
        )
    }

    private var glucoseString: String {
        guard let recent = recentGlucose else { return "—" }
        let formatter = recent.type == GlucoseType.manual.rawValue ? manualGlucoseFormatter : glucoseFormatter
        let value = recent.unfiltered ?? Decimal(recent.glucose ?? 0)
        return formatter.string(from: Double(units == .mmolL ? value.asMmolL : value) as NSNumber) ?? "—"
    }

    private var deltaString: String {
        guard let delta else { return "—" }
        let converted = units == .mmolL ? delta.asMmolL : Decimal(delta)
        let value = deltaFormatter.string(from: converted as NSNumber) ?? "—"
        return value + " " + units.rawValue
    }

    private var ageString: String {
        guard let recent = recentGlucose else { return "—" }
        let minutesAgo = timerDate.timeIntervalSince(recent.dateString) / 60
        if minutesAgo <= 1 {
            return NSLocalizedString("Now", comment: "")
        }
        let text = timeAgoFormatter.string(for: Double(minutesAgo)) ?? ""
        return text + " " + NSLocalizedString("min", comment: "Short form for minutes")
    }

    private var trendSymbol: String {
        guard let direction = recentGlucose?.direction else { return "arrow.right" }
        switch direction {
        case .doubleUp, .tripleUp:
            return "arrow.up"
        case .singleUp:
            return "arrow.up"
        case .fortyFiveUp:
            return "arrow.up.right"
        case .flat:
            return "arrow.right"
        case .fortyFiveDown:
            return "arrow.down.right"
        case .doubleDown, .singleDown, .tripleDown:
            return "arrow.down"
        case .none, .notComputable, .rateOutOfRange:
            return "arrow.right"
        }
    }

    private var sageBadge: some View {
        Group {
            if let date = recentGlucose?.sessionStartDate {
                let sensorAge: TimeInterval = -date.timeIntervalSinceNow
                let expiration = sensordays - sensorAge
                let secondsOfDay = 8.64E4
                let lineColor: Color = sensorAge >= sensordays - secondsOfDay
                    ? .red
                    : sensorAge >= sensordays - secondsOfDay * 2
                        ? .orange
                        : EsseLineaTheme.accent
                let minutesAndHours = (displayExpiration && expiration < secondsOfDay) ||
                    (displaySAGE && sensorAge < secondsOfDay)
                let text = !minutesAndHours
                    ? (remainingTimeFormatterDays.string(from: displayExpiration ? expiration : sensorAge) ?? "")
                    : (remainingTimeFormatter.string(from: displayExpiration ? expiration : sensorAge) ?? "")

                Text(text.replacingOccurrences(of: ",", with: " "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EsseLineaTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(EsseLineaTheme.surfaceElevated)
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(lineColor.opacity(0.85), lineWidth: 1.5)
                            }
                    )
            }
        }
    }

    private var glucoseColor: Color {
        let whichGlucose = recentGlucose?.glucose ?? 0
        guard lowGlucose < highGlucose else { return EsseLineaTheme.textPrimary }

        if alarm != nil {
            return .loopRed
        }

        switch whichGlucose {
        case 0 ..< Int(lowGlucose):
            return .loopRed
        case Int(lowGlucose) ..< Int(highGlucose):
            return .loopGreen
        case Int(highGlucose)...:
            return .loopYellow
        default:
            return EsseLineaTheme.textPrimary
        }
    }
}
