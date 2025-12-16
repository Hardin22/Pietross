import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        //reads keys
        self.client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseUrl)!,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(
                    encoder: {
                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .iso8601
                        return encoder
                    }(),
                    decoder: {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .custom { decoder in
                            let container = try decoder.singleValueContainer()
                            let dateString = try container.decode(String.self)

                            // 1. Try standard ISO8601 (with fractional seconds support)
                            let isoFormatter = ISO8601DateFormatter()
                            isoFormatter.formatOptions = [
                                .withInternetDateTime, .withFractionalSeconds,
                            ]
                            if let date = isoFormatter.date(from: dateString) {
                                return date
                            }

                            // 2. Try standard ISO8601 (without fractional seconds)
                            isoFormatter.formatOptions = [.withInternetDateTime]
                            if let date = isoFormatter.date(from: dateString) {
                                return date
                            }

                            // 3. Try yyyy-MM-dd (for photo_date)
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            formatter.locale = Locale(identifier: "en_US_POSIX")
                            formatter.timeZone = TimeZone(secondsFromGMT: 0)
                            if let date = formatter.date(from: dateString) {
                                return date
                            }

                            throw DecodingError.dataCorruptedError(
                                in: container,
                                debugDescription:
                                    "Date string does not match format expected by formatter."
                            )
                        }
                        return decoder
                    }()
                ),
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
