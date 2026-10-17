import Foundation

struct SafeServerErrorResponse: Decodable, Sendable {
    let availability: String?
    let readableMessage: String?
    let status: String?
    let reason: String?
    let upstreamStatus: Int?

    private enum CodingKeys: String, CodingKey { case detail }

    private struct StructuredDetail: Decodable {
        let state: String?
        let headline: String?
        let message: String?
        let reason: String?
        let status: String?
        let upstreamStatus: Int?

        enum CodingKeys: String, CodingKey {
            case headline, message, reason, status, state
            case upstreamStatus = "upstream_status"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let detail = try? container.decode(StructuredDetail.self, forKey: .detail) {
            availability = detail.state
            let primary = detail.message ?? detail.headline ?? detail.state.flatMap { ValuationAvailability(rawValue: $0)?.label }
            let category = detail.reason ?? detail.status
            if let primary, !primary.isEmpty, let category, !category.isEmpty {
                readableMessage = "\(primary) (\(category))"
            } else {
                readableMessage = primary
            }
            status = detail.status
            reason = detail.reason
            upstreamStatus = detail.upstreamStatus
            return
        }

        availability = nil
        readableMessage = try? container.decode(String.self, forKey: .detail)
        status = nil
        reason = nil
        upstreamStatus = nil
    }

    func diagnostic(httpStatus: Int) -> String {
        "httpStatus=\(httpStatus) "
            + "status=\(status ?? "unknown") "
            + "reason=\(reason ?? "unknown") "
            + "upstreamStatus=\(upstreamStatus.map(String.init) ?? "unknown")"
    }
}
