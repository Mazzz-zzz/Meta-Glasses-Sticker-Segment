//
//  MainAppView.swift
//  meta-stickers
//

import MWDATCore
import SwiftUI

struct MainAppView: View {
    let wearables: WearablesInterface
    @ObservedObject private var viewModel: WearablesViewModel

    init(wearables: WearablesInterface, viewModel: WearablesViewModel) {
        self.wearables = wearables
        self.viewModel = viewModel
    }

    var body: some View {
        if viewModel.registrationState == .registered || viewModel.hasMockDevice {
            StreamSessionView(wearables: wearables, wearablesVM: viewModel)
        } else {
            HomeScreenView(viewModel: viewModel)
        }
    }
}
