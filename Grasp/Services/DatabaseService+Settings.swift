import Foundation

extension DatabaseService {
    // Settings
    func getSetting(key: String) -> String? { row("SELECT value FROM settings WHERE key=?", [key])?["value"] as? String }
    func setSetting(key: String, value: String) { run("INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [key, value]) }
}
