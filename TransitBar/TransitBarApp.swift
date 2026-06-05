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
            Text(viewModel.menuBarTitle)
        }

        Window("Favorites", id: "favorites") {
            FavoritesWindowView(viewModel: viewModel)
        }
        .defaultSize(width: 760, height: 460)
    }
}
