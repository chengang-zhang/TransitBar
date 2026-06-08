//
//  TransitBarApp.swift
//  TransitBar
//
//  Created by Chengang Zhang on 6/5/26.
//

import SwiftUI

@main
struct TransitBarApp: App {
    @StateObject private var viewModel: TransitBarViewModel

    init() {
        if let apiKey = OneBusAwayAPIKeyProvider.apiKey() {
            let client = OneBusAwayClient(apiKey: apiKey)
            let repository = OneBusAwayTransitRepository(client: client)
            _viewModel = StateObject(wrappedValue: TransitBarViewModel(repository: repository))
        } else {
            let repository = FailingTransitRepository(error: OneBusAwayConfigurationError.missingAPIKey)
            _viewModel = StateObject(wrappedValue: TransitBarViewModel(repository: repository))
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            if let departure = viewModel.primaryDeparture {
                HStack(spacing: 4) {
                    RouteBadgeView(departure: departure)
                    Text(viewModel.minutesText(for: departure.departureTime))
                }
                .accessibilityLabel(viewModel.menuBarTitle)
            } else {
                Text(viewModel.menuBarTitle)
            }
        }
        .menuBarExtraStyle(.window)

        Window("TransitBar", id: "favorites") {
            FavoritesWindowView(viewModel: viewModel)
        }
        .defaultSize(width: 1080, height: 560)
    }
}
