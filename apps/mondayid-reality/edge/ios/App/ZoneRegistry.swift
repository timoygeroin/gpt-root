import Foundation
import SwiftUI

struct AlertZone: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let name_en: String
    let name_ru: String
    let name_ar: String
    let zone: String
    let zone_en: String
    let zone_ru: String
    let zone_ar: String
    let countdown: Int
    let lat: Double
    let lng: Double
    let value: String

    func displayName(for language: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        switch language {
        case "he": return name.isEmpty ? value : name
        case "ru": return name_ru.isEmpty ? (name_en.isEmpty ? value : name_en) : name_ru
        case "ar": return name_ar.isEmpty ? (name_en.isEmpty ? value : name_en) : name_ar
        default: return name_en.isEmpty ? value : name_en
        }
    }

    func zoneName(for language: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        switch language {
        case "he": return zone
        case "ru": return zone_ru.isEmpty ? zone_en : zone_ru
        case "ar": return zone_ar.isEmpty ? zone_en : zone_ar
        default: return zone_en.isEmpty ? zone : zone_en
        }
    }

    var searchableAliases: [String] { [name, name_en, name_ru, name_ar, value, zone, zone_en, zone_ru, zone_ar] }
}

@MainActor
final class ZoneRegistry: ObservableObject {
    @Published private(set) var zones: [AlertZone] = []
    @Published private(set) var loadFailure: String?

    private var byID: [Int: AlertZone] = [:]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "oref-cities", withExtension: "json") else {
            loadFailure = "REGISTRY_RESOURCE_MISSING"
            return
        }
        do {
            let decoded = try JSONDecoder().decode([AlertZone].self, from: Data(contentsOf: url))
                .filter { $0.id != 0 && $0.value.lowercased() != "all" && !$0.value.isEmpty }
            zones = decoded
            byID = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
            if decoded.count < 500 { loadFailure = "REGISTRY_SUSPICIOUSLY_SMALL" }
        } catch {
            loadFailure = "REGISTRY_DECODE_FAILED"
        }
    }

    func zone(id: Int) -> AlertZone? { byID[id] }

    func officialAreaValues(for ids: Set<Int>) -> Set<String> {
        Set(ids.compactMap { byID[$0]?.value })
    }

    func displaySummary(for ids: Set<Int>, limit: Int = 2) -> String {
        let names = ids.compactMap { byID[$0]?.displayName() }.sorted()
        guard !names.isEmpty else { return String(localized: "Not set") }
        if names.count <= limit { return names.joined(separator: ", ") }
        return names.prefix(limit).joined(separator: ", ") + " +\(names.count - limit)"
    }

    func search(_ query: String) -> [AlertZone] {
        let q = normalize(query)
        guard !q.isEmpty else { return Array(zones.prefix(250)) }
        return zones.filter { zone in
            zone.searchableAliases.contains { normalize($0).contains(q) }
        }.prefix(250).map { $0 }
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
