import Foundation

struct Player: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var email: String
    var displayName: String
    var avatarURL: String?
    var createdAt: Date = Date()
}
