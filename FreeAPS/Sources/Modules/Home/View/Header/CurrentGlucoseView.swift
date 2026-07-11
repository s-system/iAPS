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

    @Environment(\.colorScheme) private var colorScheme

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = units == .mmolL ? 1 : 0
        formatter.minimumFractionDigits = units == .mmolL ? 1 : 0
        formatter.roundingMode = .halfUp
        return formatter
    }

    private var deltaFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = units == .mmolL ? 1 : 0
        formatter.minimumFractionDigits = units == .mmolL ? 1 : 0
        formatter.positivePrefix = "+"
        return formatter
    }

    private var timeAgoFormatter: NumberFormatter {
        let formatter = NumberFormatter()
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
        ZStack {
            if let recent = recentGlucose {
                glucoseContent(recent)

                if !scrolling, displayDelta, let delta {
                    deltaBadge(delta)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .centerTrailing)
                        .padding(.trailing, 54)
                }

                if !scrolling, displayExpiration || displaySAGE {
                    sensorBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 18)
                        .padding(.trailing, 18)
                }
            }
        }
        .dynamicTypeSize(.medium ... .xLarge)
    }

    @ViewBuilder private func glucoseContent(_ recent: BloodGlucose) -> some View {
        let value = recent.unfiltered.map {
            glucoseFormatter.string(from: Double(units == .mmolL ? $0.asMmolL : $0) as NSNumber) ?? ""
        } ?? "--"
        let minutesAgo = timerDate.timeIntervalSince(recent.dateString) / 60
        let age = timeAgoFormatter.string(for: Double(minutesAgo)) ?? "0"

        VStack(spacing: scrolling ? 0 : 4) {
            HStack(alignment: .firstTextBaseline, spacing: scrolling ? 5 : 10) {
                Text(value)
                    .font(.system(size: scrolling ? 30 : 62, weight: .semibold, design: .rounded))
                    .tracking(-2)
                    .foregroundStyle(glucoseColor)
                    .contentTransition(.numericText())

                Image(systemName: trendSymbol)
                    .font(.system(size: scrolling ? 22 : 34, weight: .semibold))
                    .foregroundStyle(glucoseColor)
                    .accessibilityHidden(true)
            }

            if !scrolling {
                HStack(spacing: 5) {
                    Text(units.rawValue)
                    Text("•")
                    Text(
                        minutesAgo <= 1
                            ? NSLocalizedString("Now", comment: "")
                            : age + " " + NSLocalizedString("min", comment: "Short form for minutes")
                    )
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(EsseLineaTheme.textSecondary)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: recent.glucose)
    }

    private func deltaBadge(_ deltaValue: Int) -> some View {
        let converted = units == .mmolL ? deltaValue.asMmolL : Decimal(deltaValue)
        let value = deltaFormatter.string(from: converted as NSNumber) ?? "--"

        return VStack(alignment: .leading, spacing: 1) {
            Text(NSLocalizedString("Change", comment: "Glucose delta"))
                .font(.caption2)
                .foregroundStyle(EsseLineaTheme.textSecondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(EsseLineaTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(EsseLineaTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(EsseLineaTheme.divider, lineWidth: 1)
        }
    }

    private var sensorBadge: some View {
        Group {
            if let date = recentGlucose?.sessionStartDate {
                let sensorAge = -date.timeIntervalSinceNow
                let expiration = sensordays - sensorAge
                let secondsOfDay = 8.64E4
                let isUrgent = expiration <= secondsOfDay
                let isWarning = expiration <= 2 * secondsOfDay
                let showHours = (displayExpiration && expiration < secondsOfDay) || (displaySAGE && sensorAge < secondsOfDay)
                let rawText = showHours
                    ? remainingTimeFormatter.string(from: displayExpiration ? expiration : sensorAge)
                    : remainingTimeFormatterDays.string(from: displayExpiration ? expiration : sensorAge)
                let text = (rawText ?? "--").replacingOccurrences(of: ",", with: " ")

                HStack(spacing: 6) {
                    Image(systemName: displayExpiration ? "hourglass" : "sensor.tag.radiowaves.forward")
                        .font(.caption.weight(.semibold))
                    Text(text)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(isUrgent ? Color.red : isWarning ? Color.orange : EsseLineaTheme.textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background {
                    Capsule(style: .continuous)
                        .fill(EsseLineaTheme.surface)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isUrgent ? Color.red.opacity(0.8) : isWarning ? Color.orange.opacity(0.8) : EsseLineaTheme.divider, lineWidth: 1.2)
                }
            }
        }
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
        case .singleDown:
            return "arrow.down"
        case .doubleDown, .tripleDown:
            return "arrow.down"
        case .none, .notComputable, .rateOutOfRange:
            return "minus"
        }
    }

    private var glucoseColor: Color {
        if !alwaysUseColors {
            return alarm == nil ? EsseLineaTheme.textPrimary : .loopRed
        }

        let glucose = recentGlucose?.glucose ?? 0
        guard lowGlucose < highGlucose else { return EsseLineaTheme.textPrimary }

        switch glucose {
        case 0 ..< Int(lowGlucose):
            return .loopRed
        case Int(lowGlucose) ..< Int(highGlucose):
            return .loopGreen
        default:
            return .loopYellow
        }
    }
}
