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
        let staticRepository = SQLiteGtfsTransitRepository()
        let realtimeProvider = CompositeRealtimeProvider(providers: [
            SoundTransitRealtimeProvider(configuration: .soundTransit),
            SoundTransitRealtimeProvider(configuration: .kingCountyMetro)
        ])
        let arrivalService = RealtimeOverlayArrivalService(
            staticArrivalService: StaticArrivalService(repository: staticRepository),
            realtimeProvider: realtimeProvider
        )
        let repository = RealtimeOverlayTransitRepository(
            baseRepository: staticRepository,
            arrivalService: arrivalService
        )
        let alertService = RealtimeAlertService(realtimeProvider: realtimeProvider)
        _viewModel = StateObject(wrappedValue: TransitBarViewModel(repository: repository, alertService: alertService))

        Task.detached(priority: .utility) {
            try? await staticRepository.warmCache()
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
