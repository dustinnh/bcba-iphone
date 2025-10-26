//
//  BCBATrackerApp.swift
//  BCBATracker
//
//  Main app entry point for BCBA Behavioral Data Tracker
//  A native iOS application for collecting and analyzing behavioral data
//

import SwiftUI

@main
struct BCBATrackerApp: App {

    // MARK: - State Objects
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var securityManager = SecurityManager.shared

    // MARK: - Scene Phase
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - App Initialization
    init() {
        configureApp()
    }

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            Group {
                if securityManager.isAuthenticated {
                    // Main app interface
                    ContentView()
                        .environment(\.managedObjectContext, dataManager.viewContext)
                        .environmentObject(dataManager)
                        .environmentObject(securityManager)
                } else {
                    // Authentication screen
                    AuthenticationView()
                        .environmentObject(securityManager)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
    }

    // MARK: - Configuration

    private func configureApp() {
        // Set default user preferences if first launch
        registerDefaults()

        // Configure appearance
        configureAppearance()

        // Enable haptics by default
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            HapticManager.enable()
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }

        #if DEBUG
        print("🚀 BCBATracker initialized")
        print("📱 Platform: iOS \(UIDevice.current.systemVersion)")
        print("🔐 Biometric: \(securityManager.biometricType().displayName)")
        #endif
    }

    private func registerDefaults() {
        let defaults: [String: Any] = [
            Constants.UserDefaultsKeys.enableHaptics: true,
            Constants.UserDefaultsKeys.autoSyncEnabled: true,
            Constants.UserDefaultsKeys.hasCompletedOnboarding: false
        ]

        UserDefaults.standard.register(defaults: defaults)
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active
            handleAppActivation()

        case .inactive:
            // App about to become inactive (e.g., phone call, notification)
            handleAppDeactivation()

        case .background:
            // App moved to background
            handleAppBackground()

        @unknown default:
            break
        }
    }

    private func handleAppActivation() {
        #if DEBUG
        print("📱 App activated")
        #endif

        // Trigger sync if enabled
        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.autoSyncEnabled) {
            Task {
                await dataManager.syncWithCloudKit()
            }
        }
    }

    private func handleAppDeactivation() {
        #if DEBUG
        print("📱 App deactivating")
        #endif

        // Save any pending changes
        dataManager.save()
    }

    private func handleAppBackground() {
        #if DEBUG
        print("📱 App moved to background")
        #endif

        // Save context and clear sensitive data if needed
        dataManager.save()

        // Log out after timeout (optional security measure)
        // For now, we keep user authenticated between sessions
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @State private var isAuthenticating = false
    @State private var showError = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Constants.Colors.primary.opacity(0.8),
                    Constants.Colors.secondary.opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: Constants.UI.paddingLarge) {
                Spacer()

                // App icon and name
                VStack(spacing: Constants.UI.paddingMedium) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text(Constants.App.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Behavioral Data Collection for Special Education")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Authentication button
                VStack(spacing: Constants.UI.paddingMedium) {
                    Button(action: authenticate) {
                        HStack {
                            Image(systemName: securityManager.biometricType().iconName)
                                .font(.title3)

                            Text("Authenticate with \(securityManager.biometricType().displayName)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Constants.UI.preferredTouchTarget)
                        .background(Color.white)
                        .foregroundColor(Constants.Colors.primary)
                        .cornerRadius(Constants.UI.cornerRadiusMedium)
                    }
                    .disabled(isAuthenticating)

                    if securityManager.biometricType() == .none {
                        Text("Biometric authentication not available")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    #if DEBUG
                    // Development bypass button
                    Button(action: bypassAuthentication) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)

                            Text("Skip Authentication (Debug Only)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(Constants.UI.cornerRadiusSmall)
                    }
                    #endif
                }
                .padding(.horizontal, Constants.UI.paddingLarge)
                .padding(.bottom, Constants.UI.paddingXLarge)
            }
        }
        .alert("Authentication Failed", isPresented: $showError) {
            Button("Try Again") {
                showError = false
            }
        } message: {
            if let error = securityManager.authenticationError {
                Text(error)
            }
        }
    }

    private func authenticate() {
        isAuthenticating = true

        Task {
            let success = await securityManager.authenticateUser()

            await MainActor.run {
                isAuthenticating = false

                if !success {
                    showError = true
                    HapticManager.error()
                } else {
                    HapticManager.success()
                }
            }
        }
    }

    #if DEBUG
    private func bypassAuthentication() {
        securityManager.bypassAuthentication()
        HapticManager.success()
    }
    #endif
}

// MARK: - Preview

// App-level preview not supported in Xcode
// #Preview("App Launch") {
//     BCBATrackerApp()
// }

#Preview("Authentication") {
    AuthenticationView()
        .environmentObject(SecurityManager.shared)
}
