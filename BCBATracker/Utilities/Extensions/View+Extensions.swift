//
//  View+Extensions.swift
//  BCBATracker
//
//  SwiftUI View extensions for common modifiers
//

import SwiftUI

extension View {

    // MARK: - Conditional Modifiers

    /// Conditionally apply a modifier
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply a modifier if value is not nil
    @ViewBuilder
    func ifLet<T, Transform: View>(
        _ value: T?,
        transform: (Self, T) -> Transform
    ) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }

    // MARK: - Corner Radius

    /// Apply corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    // MARK: - Card Style

    /// Apply card styling (shadow and background)
    func cardStyle(
        backgroundColor: Color = Color(.systemBackground),
        shadowRadius: CGFloat = 4
    ) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(Constants.UI.cornerRadiusMedium)
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 2)
    }

    // MARK: - Loading State

    /// Show loading overlay
    func loadingOverlay(isLoading: Bool) -> some View {
        self.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
    }

    // MARK: - Error Alert

    /// Show error alert
    func errorAlert(error: Binding<Error?>) -> some View {
        self.alert("Error", isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Button("OK") {
                error.wrappedValue = nil
            }
        } message: {
            if let error = error.wrappedValue {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Keyboard

    /// Hide keyboard when tapped
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }

    // MARK: - Navigation

    /// Add navigation bar title and toolbar
    func navigationSetup(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .large
    ) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
    }

    // MARK: - Accessibility

    /// Make view accessible for VoiceOver
    func accessible(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .if(hint != nil) { view in
                view.accessibilityHint(hint!)
            }
            .accessibilityAddTraits(traits)
    }

    // MARK: - Animation

    /// Add spring animation
    func springAnimation(delay: Double = 0) -> some View {
        self.animation(
            .spring(response: Constants.UI.animationDuration,
                   dampingFraction: Constants.UI.animationSpring),
            value: UUID()
        )
    }

    // MARK: - Empty State

    /// Show empty state when condition is true
    func emptyState<EmptyContent: View>(
        isEmpty: Bool,
        @ViewBuilder emptyContent: () -> EmptyContent
    ) -> some View {
        ZStack {
            self.opacity(isEmpty ? 0 : 1)

            if isEmpty {
                emptyContent()
            }
        }
    }
}

// MARK: - RoundedCorner Shape

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Button Style Extensions

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.preferredTouchTarget)
            .background(
                isEnabled ? Constants.Colors.primary : Color.gray
            )
            .cornerRadius(Constants.UI.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.6)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Constants.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.preferredTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium)
                    .stroke(Constants.Colors.primary, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.preferredTouchTarget)
            .background(Constants.Colors.error)
            .cornerRadius(Constants.UI.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
