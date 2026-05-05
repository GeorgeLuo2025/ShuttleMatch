import Foundation

enum Gender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case nonBinary = "non_binary"
    case preferNotToSay = "prefer_not_to_say"

    var label: String {
        switch self {
        case .male: return String(localized: "gender_male")
        case .female: return String(localized: "gender_female")
        case .nonBinary: return String(localized: "gender_non_binary")
        case .preferNotToSay: return String(localized: "gender_prefer_not_to_say")
        }
    }
}

struct Player: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var email: String
    var displayName: String
    var avatarURL: String?
    var gender: Gender?
    var birthYear: Int?
    var createdAt: Date = Date()
}
