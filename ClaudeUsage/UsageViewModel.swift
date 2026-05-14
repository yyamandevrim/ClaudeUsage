import Foundation
import Security
import ServiceManagement
import SwiftUI
import UserNotifications

struct HistoryPoint: Codable {
    let timestamp: Date
    let s5hPct: Int
    let s7dPct: Int
}

enum SparklineMode: String {
    case fiveHour, sevenDay
}

class UsageViewModel: ObservableObject {
    @Published var s5hPct: Int = 0
    @Published var s5hMins: Int = 0
    @Published var s7dPct: Int = 0
    @Published var s7dMins: Int = 0
    @Published var status: String = "—"
    @Published var lastUpdate: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var history: [HistoryPoint] = []
    @Published var tokenExpiresAt: Date? = nil
    @Published var sparklineMode: SparklineMode = .fiveHour
    @Published var pollIntervalSecs: Int = 60

    var lastNotifiedThreshold: Int = 0
    var tokenExpiryNotified: Bool = false

    private var pollingTask: Task<Void, Never>? = nil

    init() {
        let saved = UserDefaults.standard.integer(forKey: "pollIntervalSecs")
        pollIntervalSecs = saved > 0 ? saved : 60
        loadHistory()
        requestNotificationPermission()
        startPolling()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func startPolling() {
        pollingTask?.cancel()
        let interval = UInt64(pollIntervalSecs) * 1_000_000_000
        pollingTask = Task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                if !Task.isCancelled {
                    await refresh()
                }
            }
        }
    }

    func setPollInterval(_ secs: Int) {
        pollIntervalSecs = secs
        UserDefaults.standard.set(secs, forKey: "pollIntervalSecs")
        startPolling()
    }

    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
        } catch {
            // silently fail if not running from /Applications
        }
    }

    func refresh() async {
        guard let credentials = readCredentials() else {
            await MainActor.run {
                self.errorMessage = "credentials_missing"
                self.status = "—"
            }
            return
        }

        await MainActor.run {
            self.tokenExpiresAt = credentials.expiresAt
            self.checkTokenExpiry()
        }

        do {
            let result = try await fetchUsage(token: credentials.token)
            await MainActor.run {
                self.s5hPct = result.s5hPct
                self.s5hMins = result.s5hMins
                self.s7dPct = result.s7dPct
                self.s7dMins = result.s7dMins
                self.status = result.status
                self.lastUpdate = Date()
                self.errorMessage = nil

                let point = HistoryPoint(timestamp: Date(), s5hPct: result.s5hPct, s7dPct: result.s7dPct)
                self.history.append(point)
                let cutoff = Date().addingTimeInterval(-86400)
                self.history = self.history.filter { $0.timestamp > cutoff }
                self.saveHistory()
                self.checkNotifications()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func checkTokenExpiry() {
        guard let exp = tokenExpiresAt else { return }
        let hoursLeft = exp.timeIntervalSinceNow / 3600
        if hoursLeft < 24 && !tokenExpiryNotified {
            let h = max(0, Int(hoursLeft))
            fireNotification(
                title: "Claude Token Expiring Soon",
                body: "OAuth token expires in \(h)h. Run `claude` to re-authenticate."
            )
            tokenExpiryNotified = true
        }
        if hoursLeft >= 24 {
            tokenExpiryNotified = false
        }
    }

    var tokenExpiryWarning: String? {
        guard let exp = tokenExpiresAt else { return nil }
        let hoursLeft = exp.timeIntervalSinceNow / 3600
        if hoursLeft < 0 { return "Token expired — re-authenticate" }
        if hoursLeft < 24 { return "Token expires in \(max(0, Int(hoursLeft)))h" }
        return nil
    }

    private func checkNotifications() {
        if s5hPct >= 90 && lastNotifiedThreshold < 90 {
            fireNotification(
                title: "Claude Usage at 90%",
                body: "5h window is 90% full. Resets in \(formatMins(s5hMins))."
            )
            lastNotifiedThreshold = 90
        } else if s5hPct >= 80 && lastNotifiedThreshold < 80 {
            fireNotification(
                title: "Claude Usage at 80%",
                body: "5h window is 80% full. Resets in \(formatMins(s5hMins))."
            )
            lastNotifiedThreshold = 80
        } else if s5hPct < 80 {
            lastNotifiedThreshold = 0
        }
    }

    private func fireNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private struct Credentials {
        let token: String
        let expiresAt: Date?
    }

    private func readCredentials() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        let expiresAt: Date?
        if let ms = oauth["expiresAt"] as? Double {
            expiresAt = Date(timeIntervalSince1970: ms / 1000)
        } else {
            expiresAt = nil
        }
        return Credentials(token: token, expiresAt: expiresAt)
    }

    private struct FetchResult {
        let s5hPct: Int
        let s5hMins: Int
        let s7dPct: Int
        let s7dMins: Int
        let status: String
    }

    private func fetchUsage(token: String) async throws -> FetchResult {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.5", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let headers = http.allHeaderFields
        let now = Date().timeIntervalSince1970

        let s5hUtil = Double(headers["anthropic-ratelimit-unified-5h-utilization"] as? String ?? "0") ?? 0
        let s7dUtil = Double(headers["anthropic-ratelimit-unified-7d-utilization"] as? String ?? "0") ?? 0
        let s5hReset = Double(headers["anthropic-ratelimit-unified-5h-reset"] as? String ?? "0") ?? 0
        let s7dReset = Double(headers["anthropic-ratelimit-unified-7d-reset"] as? String ?? "0") ?? 0
        let statusStr = headers["anthropic-ratelimit-unified-5h-status"] as? String ?? "unknown"

        let s5hPct = Int((s5hUtil * 100).rounded())
        let s7dPct = Int((s7dUtil * 100).rounded())
        let s5hMins = max(0, Int((s5hReset - now) / 60))
        let s7dMins = max(0, Int((s7dReset - now) / 60))

        return FetchResult(
            s5hPct: s5hPct,
            s5hMins: s5hMins,
            s7dPct: s7dPct,
            s7dMins: s7dMins,
            status: statusStr
        )
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "usageHistory"),
              let decoded = try? JSONDecoder().decode([HistoryPoint].self, from: data) else {
            return
        }
        let cutoff = Date().addingTimeInterval(-86400)
        history = decoded.filter { $0.timestamp > cutoff }
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: "usageHistory")
    }
}

func formatMins(_ mins: Int) -> String {
    if mins < 60 {
        return "\(mins)m"
    } else if mins < 1440 {
        let h = mins / 60
        let m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    } else {
        let d = mins / 1440
        let h = (mins % 1440) / 60
        return h > 0 ? "\(d)d \(h)h" : "\(d)d"
    }
}

func usageColor(_ pct: Int) -> Color {
    if pct >= 80 { return .red }
    if pct >= 50 { return .yellow }
    return .green
}
