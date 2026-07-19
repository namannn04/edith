import EdithKit
import SwiftUI

struct InstallerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var keyFieldFocused: Bool
    @StateObject private var model = InstallerModel()

    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        Group {
            switch model.phase {
            case .license:
                licenseEntry
            case .downloading:
                downloading
            case .done:
                done
            case let .failure(failure):
                failureView(failure)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(InstallerSkin.paper(dark))
    }

    private var licenseEntry: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            productIcon
            Text("Install Edith")
                .font(InstallerSkin.serif(30, weight: .bold))
                .foregroundStyle(InstallerSkin.ink(dark))
                .padding(.top, 18)
            Text("Enter your license key")
                .font(.system(size: 14))
                .foregroundStyle(InstallerSkin.inkSoft(dark))
                .padding(.top, 5)
            TextField(
                "EDITH-XXXX-XXXX-XXXX-XXXX",
                text: Binding(get: { model.key }, set: model.updateKey)
            )
            .textFieldStyle(.plain)
            .font(InstallerSkin.mono(15, weight: .medium))
            .multilineTextAlignment(.center)
            .focused($keyFieldFocused)
            .disabled(model.activating)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(InstallerSkin.paperRaised(dark), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        model.errorMessage == nil
                            ? InstallerSkin.lineStrong(dark) : InstallerSkin.danger,
                        lineWidth: 1
                    )
            }
            .padding(.top, 20)
            .onSubmit(model.activate)
            activationButton
                .disabled(!model.canActivate || model.activating)
                .opacity(model.canActivate ? 1 : 0.55)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 12)
            Text(model.errorMessage ?? " ")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(InstallerSkin.danger)
                .frame(height: 17)
                .padding(.top, 8)
            Spacer(minLength: 18)
            if model.seatLimitHit {
                Divider()
                    .overlay(InstallerSkin.line(dark))
                Text("Keys are limited to a number of Macs")
                    .font(.system(size: 10.5))
                    .foregroundStyle(InstallerSkin.inkFaint(dark))
                    .frame(height: 42)
            }
        }
        .padding(.horizontal, 52)
        .task { keyFieldFocused = true }
    }

    private var downloading: some View {
        centeredState {
            productIcon
            Text("Install Edith")
                .font(InstallerSkin.serif(30, weight: .bold))
                .foregroundStyle(InstallerSkin.ink(dark))
                .padding(.top, 20)
            Text("Downloading Edith...")
                .font(.system(size: 14))
                .foregroundStyle(InstallerSkin.inkSoft(dark))
                .padding(.top, 6)
            Group {
                if let progress = model.downloadProgress {
                    ProgressView(value: progress)
                } else {
                    ProgressView()
                }
            }
            .progressViewStyle(.linear)
            .tint(brandAccent)
            .frame(width: 278)
            .padding(.top, 28)
            if let progress = model.downloadProgress {
                Text("\(Int(progress * 100))%")
                    .font(InstallerSkin.mono(11, weight: .medium))
                    .foregroundStyle(InstallerSkin.inkFaint(dark))
                    .padding(.top, 9)
            }
        }
    }

    private var done: some View {
        centeredState {
            stateIcon(systemName: "checkmark", color: brandAccent)
            Text("Edith is ready")
                .font(InstallerSkin.serif(30, weight: .bold))
                .foregroundStyle(InstallerSkin.ink(dark))
                .padding(.top, 20)
            Text("Opening the installer image")
                .font(.system(size: 14))
                .foregroundStyle(InstallerSkin.inkSoft(dark))
                .padding(.top, 6)
        }
    }

    private func failureView(_ failure: InstallerFailure) -> some View {
        centeredState {
            stateIcon(systemName: "exclamationmark", color: InstallerSkin.danger)
            Text(failure.title)
                .font(InstallerSkin.serif(28, weight: .bold))
                .foregroundStyle(InstallerSkin.ink(dark))
                .padding(.top, 20)
            Text(failure.message)
                .font(.system(size: 13.5))
                .foregroundStyle(InstallerSkin.inkSoft(dark))
                .multilineTextAlignment(.center)
                .frame(width: 300)
                .padding(.top, 7)
            primaryButton("Retry", action: model.retry)
                .frame(width: 278)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 24)
        }
    }

    private var productIcon: some View {
        Image(systemName: "waveform.path.ecg.rectangle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(brandAccent)
            .frame(width: 72, height: 72)
            .shadow(color: .black.opacity(dark ? 0.3 : 0.14), radius: 14, y: 7)
    }

    private func stateIcon(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 31, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 72, height: 72)
            .background(InstallerSkin.paperRaised(dark), in: Circle())
            .overlay(Circle().strokeBorder(InstallerSkin.line(dark), lineWidth: 1))
            .shadow(color: .black.opacity(dark ? 0.3 : 0.08), radius: 14, y: 7)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(brandAccent, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var activationButton: some View {
        Button(action: model.activate) {
            Group {
                if model.activating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Text(model.activationButtonTitle)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(brandAccent, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func centeredState<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Spacer()
            content()
            Spacer()
        }
        .padding(.horizontal, 52)
    }
}
