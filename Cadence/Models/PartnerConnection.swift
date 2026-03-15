import Foundation

struct PartnerConnection: Codable, Sendable {
    let connectionId: UUID
    let inviteCode: String
    let createdAt: Date
    let partnerId: UUID?

    enum CodingKeys: String, CodingKey {
        case connectionId = "id"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
        case partnerId = "partner_id"
    }
}
