//
//  ContentView.swift
//  TransitBar
//
//  Created by Chengang Zhang on 6/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TransitBar")
                .font(.title)
            Text("Use the menu bar item to view departures or manage favorite stops.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
