import ActivityKit
import CoreData
import Foundation
import HealthKit
import SwiftUI
import Swinject

@main struct FreeAPSApp: App {
    @Environment(\.scenePhase) var scenePhase

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject var dataController = CoreDataStack.shared

    // Dependencies Assembler
    // contain all dependencies Assemblies
    // TODO: Remove static key after update "Use Dependencies" logic
    private static let assembler = Assembler([
        StorageAssembly(),
        ServiceAssembly(),
        APSAssembly(),
        NetworkAssembly(),
        UIAssembly(),
        SecurityAssembly()
    ], parent: nil, defaultObjectScope: .container)

    // Temp static var
    // Use to backward compatibility with old Dependencies logic on Logger
    // TODO: Remove var after update "Use Dependencies" logic in Logger
    static let resolver: Resolver = FreeAPSApp.assembler.resolver

    // TODO: do we want this? will this work with the Router?
    // can be shared with the rest of the views with @EnvironmentObject
    @StateObject private var appServices = AppServices(assembler: assembler)

    private let healthKitMacroImporter = HealthKitMacroOnlyImporter(resolver: FreeAPSApp.resolver)

    init() {
        debug(
            .default,
            "iAPS Started: v\(Bundle.main.releaseVersionNumber ?? "")(\(Bundle.main.buildVersionNumber ?? "")) [buildDate: \(Bundle.main.buildDate)] [buildExpires: \(Bundle.main.profileExpiration ?? "")]"
        )
        isNewVersion()
        AppearanceManager.setupGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Main.RootView(resolver: FreeAPSApp.resolver)
                .tint(EsseLineaTheme.accent)
                .foregroundStyle(EsseLineaTheme.textPrimary)
                .background(EsseLineaTheme.background.ignoresSafeArea())
                .environment(\.managedObjectContext, dataController.persistentContainer.viewContext)
                .environmentObject(Icons())
                .onOpenURL(perform: handleURL)
                .environmentObject(appServices)
        }
        .onChange(of: scenePhase) {
            debug(.default, "APPLICATION PHASE: \(scenePhase)")
            if scenePhase == .active {
                appServices.deviceManager.didBecomeActive()
            }
        }
    }

    private func handleURL(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch components?.host {
        case "device-select-resp":
            FreeAPSApp.resolver.resolve(NotificationCenter.self)!.post(name: .openFromGarminConnect, object: url)
        default: break
        }
    }

    private func isNewVersion() {
        let userDefaults = UserDefaults.standard
        var version = userDefaults.string(forKey: IAPSconfig.version) ?? ""
        userDefaults.set(false, forKey: IAPSconfig.inBolusView)

        guard version.count > 1, version == (Bundle.main.releaseVersionNumber ?? "") else {
            version = Bundle.main.releaseVersionNumber ?? ""
            userDefaults.set(version, forKey: IAPSconfig.version)
            userDefaults.set(true, forKey: IAPSconfig.newVersion)
            debug(.default, "Running new version: \(version)")
            return
        }
    }
}

private final class HealthKitMacroOnlyImporter {
    private enum Nutrient {
        case protein
        case fat
        case fiber
    }

    private struct MacroGroup {
        let sourceIdentifier: String
        var date: Date
        var protein: Decimal = 0
        var fat: Decimal = 0
        var fiber: Decimal = 0
    }

    private let healthStore: HKHealthStore
    private let settingsManager: SettingsManager
    private let carbsStorage: CarbsStorage
    private let queue = DispatchQueue(label: "HealthKitMacroOnlyImporter.queue")
    private var observerQueries: [HKObserverQuery] = []

    private let matchingWindow: TimeInterval = 5

    init(resolver: Resolver) {
        healthStore = resolver.resolve(HKHealthStore.self)!
        settingsManager = resolver.resolve(SettingsManager.self)!
        carbsStorage = resolver.resolve(CarbsStorage.self)!

        startObserving()
    }

    private func startObserving() {
        guard HKHealthStore.isHealthDataAvailable(), settingsManager.settings.useAppleHealth else { return }

        let sampleTypes = [
            HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
            HKObjectType.quantityType(forIdentifier: .dietaryFiber)
        ].compactMap { $0 }

        for sampleType in sampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                guard let self else {
                    completionHandler()
                    return
                }

                if let error {
                    warning(.service, "Cannot observe HealthKit macro entries", error: error)
                    completionHandler()
                    return
                }

                self.queue.asyncAfter(deadline: .now() + 2) {
                    self.importMacroOnlyMeals(completion: completionHandler)
                }
            }

            observerQueries.append(query)
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
                if let error {
                    warning(.service, "Cannot enable background delivery for HealthKit macro entries", error: error)
                } else if success {
                    debug(.service, "HealthKit macro background delivery enabled")
                }
            }
        }

        importMacroOnlyMeals()
    }

    private func importMacroOnlyMeals(completion: (() -> Void)? = nil) {
        guard settingsManager.settings.useAppleHealth,
              let carbType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
              let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein),
              let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
              let fiberType = HKObjectType.quantityType(forIdentifier: .dietaryFiber)
        else {
            completion?()
            return
        }

        let startDate = Date().addingTimeInterval(-1.days.timeInterval)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: [])
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let group = DispatchGroup()
        let lock = NSLock()

        var carbs: [HKQuantitySample] = []
        var proteins: [HKQuantitySample] = []
        var fats: [HKQuantitySample] = []
        var fibers: [HKQuantitySample] = []

        func load(_ sampleType: HKQuantityType, assign: @escaping ([HKQuantitySample]) -> Void) {
            group.enter()
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: 200,
                sortDescriptors: sortDescriptors
            ) { _, results, error in
                if let error {
                    warning(.service, "Cannot load HealthKit nutrition samples", error: error)
                }

                lock.lock()
                assign((results as? [HKQuantitySample]) ?? [])
                lock.unlock()
                group.leave()
            }
            healthStore.execute(query)
        }

        load(carbType) { carbs = $0 }
        load(proteinType) { proteins = $0 }
        load(fatType) { fats = $0 }
        load(fiberType) { fibers = $0 }

        group.notify(queue: queue) { [weak self] in
            guard let self else {
                completion?()
                return
            }

            var macroGroups: [MacroGroup] = []

            func add(_ samples: [HKQuantitySample], nutrient: Nutrient) {
                for sample in samples where sample.quantity.doubleValue(for: .gram()) > 0 {
                    let sourceIdentifier = sample.sourceRevision.source.bundleIdentifier
                    let value = Decimal(sample.quantity.doubleValue(for: .gram()))

                    if let index = macroGroups.firstIndex(where: {
                        $0.sourceIdentifier == sourceIdentifier &&
                            abs($0.date.timeIntervalSince(sample.startDate)) <= self.matchingWindow
                    }) {
                        switch nutrient {
                        case .protein:
                            macroGroups[index].protein += value
                        case .fat:
                            macroGroups[index].fat += value
                        case .fiber:
                            macroGroups[index].fiber += value
                        }
                    } else {
                        var newGroup = MacroGroup(sourceIdentifier: sourceIdentifier, date: sample.startDate)
                        switch nutrient {
                        case .protein:
                            newGroup.protein = value
                        case .fat:
                            newGroup.fat = value
                        case .fiber:
                            newGroup.fiber = value
                        }
                        macroGroups.append(newGroup)
                    }
                }
            }

            add(proteins, nutrient: .protein)
            add(fats, nutrient: .fat)
            add(fibers, nutrient: .fiber)

            let recentEntries = self.carbsStorage.recent()

            let entries = macroGroups.compactMap { macroGroup -> CarbsEntry? in
                let hasMatchingCarbs = carbs.contains { carbSample in
                    carbSample.sourceRevision.source.bundleIdentifier == macroGroup.sourceIdentifier &&
                        carbSample.quantity.doubleValue(for: .gram()) > 0 &&
                        abs(carbSample.startDate.timeIntervalSince(macroGroup.date)) <= self.matchingWindow
                }

                guard !hasMatchingCarbs,
                      macroGroup.protein > 0 || macroGroup.fat > 0 || macroGroup.fiber > 0
                else { return nil }

                let isDuplicate = recentEntries.contains { entry in
                    guard entry.enteredBy == CarbsEntry.appleHealth else { return false }
                    let entryDate = entry.actualDate ?? entry.createdAt
                    return entry.carbs == 0 &&
                        abs(entryDate.timeIntervalSince(macroGroup.date)) <= self.matchingWindow &&
                        entry.protein == macroGroup.protein &&
                        entry.fat == macroGroup.fat &&
                        entry.fiber == macroGroup.fiber
                }

                guard !isDuplicate else { return nil }

                let timestamp = Int(macroGroup.date.timeIntervalSince1970 * 1000)
                let source = macroGroup.sourceIdentifier.replacingOccurrences(of: ".", with: "-")

                return CarbsEntry(
                    id: "\(CarbsEntry.appleHealth)-macros-\(source)-\(timestamp)",
                    createdAt: macroGroup.date,
                    actualDate: macroGroup.date,
                    carbs: 0,
                    fat: macroGroup.fat,
                    protein: macroGroup.protein,
                    fiber: macroGroup.fiber,
                    note: "Apple Health",
                    enteredBy: CarbsEntry.appleHealth,
                    isFPU: false,
                    micronutrient: nil
                )
            }

            entries.forEach { self.carbsStorage.storeCarbs([$0]) }

            if entries.isNotEmpty {
                debug(.service, "Imported \(entries.count) macro-only meals from HealthKit")
            }

            completion?()
        }
    }
}
