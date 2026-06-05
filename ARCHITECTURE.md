# TransitBar Architecture

## Folder Structure

```text
TransitBar/
  Domain/
    Models/
    Repositories/
  Data/
    GTFS/
    Persistence/
    Repositories/
  Presentation/
    ViewModels/
    Views/
  Resources/
    GTFS/
```

## Overview

TransitBar follows MVVM + Repository.

- Views render state and forward user intent.
- ViewModels own UI state, timers, loading state, and persistence coordination.
- Repositories own data retrieval and departure calculations.
- Persistence is isolated behind `UserSettingsStore`.
- GTFS parsing is isolated from SwiftUI and can be reused by future repository implementations.

## Repository Swapping

Presentation code depends on the `TransitRepository` protocol:

```swift
protocol TransitRepository {
    func searchStops(query: String) async throws -> [TransitStop]
    func getDepartures(stopId: String) async throws -> [Departure]
}
```

V0 injects `StaticGtfsTransitRepository`. V1 can inject `OneBusAwayTransitRepository` without changing views.

## Models

- `TransitStop`: searchable GTFS stop result.
- `FavoriteStop`: persisted user favorite.
- `Departure`: UI-ready departure result.
- `StopLabel`: future semantic labels, currently `home` and `work`.

## GTFS Parsing

The static repository loads these bundled files from `Resources/GTFS`:

- `stops.txt`
- `routes.txt`
- `trips.txt`
- `stop_times.txt`
- `calendar.txt`
- `calendar_dates.txt`

Parsing flow:

1. Read each CSV file from the bundle.
2. Parse CSV rows using header names.
3. Build lookup dictionaries for stops, routes, trips, service calendars, and calendar date exceptions.
4. Index stop times by `stop_id`.
5. Convert GTFS times to seconds after the service day midnight.

GTFS allows times beyond `24:00:00`. TransitBar preserves those hour values, so `25:30:00` becomes 25.5 hours after the service day starts. When calculating upcoming departures, the repository checks recent service days as well as today so after-midnight trips from the previous service day still appear correctly.

## Departure Calculation

For a stop:

1. Look up all `stop_times` for that `stop_id`.
2. Consider service dates around the current date.
3. Check whether each trip's `service_id` is active via `calendar.txt` and `calendar_dates.txt`.
4. Convert the GTFS departure time into an absolute `Date`.
5. Keep future departures, sort by time, and return the next results.

`calendar_dates.txt` exceptions override weekly calendar rules.
