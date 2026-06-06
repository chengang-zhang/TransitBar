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
        let repository: TransitRepository
        do {
            repository = try StaticGtfsTransitRepository()
        } catch {
            repository = FailingTransitRepository(error: error)
        }

        _viewModel = StateObject(wrappedValue: TransitBarViewModel(repository: repository))
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

        Window("Favorites", id: "favorites") {
            FavoritesWindowView(viewModel: viewModel)
        }
        .defaultSize(width: 760, height: 460)
    }
}
