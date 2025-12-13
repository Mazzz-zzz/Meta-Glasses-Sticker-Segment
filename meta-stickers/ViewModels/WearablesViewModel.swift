//
//  WearablesViewModel.swift
//  meta-stickers
//

import Combine
import MWDATCore
import SwiftUI

#if DEBUG
import MWDATMockDevice
#endif

@MainActor
class WearablesViewModel: ObservableObject {
    @Published var devices: [DeviceIdentifier]
    @Published var hasMockDevice: Bool
    @Published var registrationState: RegistrationState
    @Published var showGettingStartedSheet: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private var registrationTask: Task<Void, Never>?
    private var deviceStreamTask: Task<Void, Never>?
    private let wearables: WearablesInterface

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.devices = wearables.devices
        self.hasMockDevice = false
        self.registrationState = wearables.registrationState

        registrationTask = Task {
            for await registrationState in wearables.registrationStateStream() {
                let previousState = self.registrationState
                self.registrationState = registrationState
                if self.showGettingStartedSheet == false && registrationState == .registered && previousState != .registered {
                    self.showGettingStartedSheet = true
                }
                if registrationState == .registered {
                    await setupDeviceStream()
                }
            }
        }
    }

    deinit {
        registrationTask?.cancel()
        deviceStreamTask?.cancel()
    }

    private func setupDeviceStream() async {
        if let task = deviceStreamTask, !task.isCancelled {
            task.cancel()
        }

        deviceStreamTask = Task {
            for await devices in wearables.devicesStream() {
                self.devices = devices
                #if DEBUG
                self.hasMockDevice = !MockDeviceKit.shared.pairedDevices.isEmpty
                #endif
            }
        }
    }

    func connectGlasses() {
        guard registrationState != .registering else { return }
        do {
            try wearables.startRegistration()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func disconnectGlasses() {
        do {
            try wearables.startUnregistration()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func showError(_ error: String) {
        errorMessage = error
        showError = true
    }

    func dismissError() {
        showError = false
    }
}
