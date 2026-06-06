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
        _viewModel = StateObject(wrappedValue: TransitBarViewModel(repository: LazyStaticGtfsTransitRepository()))
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
