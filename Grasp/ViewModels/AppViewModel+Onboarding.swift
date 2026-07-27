import Foundation

extension AppViewModel {
    // MARK: - Onboarding (Spec 17)
    func checkOnboarding() {
        onboardingChecked = true
        showOnboarding = db.getSetting(key: "onboardingComplete") != "true"
    }
    func completeOnboarding(_ mode: String) {
        db.setSetting(key: "mode", value: mode); db.setSetting(key: "onboardingComplete", value: "true")
        showOnboarding = false
    }
}
