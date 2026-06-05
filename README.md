# TransitBar

TransitBar is a lightweight native macOS menu bar application for quickly checking upcoming transit departures from favorite stops. It is designed to feel like a system utility rather than a full transit app.

Primary user question:

> When is my next train or bus leaving?

## Product Roadmap

### V0

Static GTFS schedule data only.

Purpose:

- Validate menu bar UX
- Validate architecture
- Build stop search
- Build favorite management
- Build departure calculations

No network access required.

### V1

Replace static GTFS departures with OneBusAway data.

Add:

- Real-time arrivals
- Predicted departure times
- Refresh intervals
- Stale data handling

UI should not require modification.

### V2

Commuter quality-of-life features:

- Home label
- Work label
- Keyboard shortcuts
- Notifications
- Quick stop switching

## Non Goals

Out of scope:

- Trip planning
- Route planning
- Maps
- Nearby stop detection
- Location permissions
- User accounts
- Cloud sync
- Custom backend
- GTFS-Realtime ingestion
- iOS app

## Architecture

TransitBar uses MVVM + Repository.

### Layers

Presentation:

- SwiftUI views
- ViewModels

Domain:

- Models
- Repository protocols

Data:

- GTFS parser
- Repository implementations
- Persistence

## Repository Contract

The UI and ViewModels depend only on `TransitRepository`.

```swift
protocol TransitRepository {
    func searchStops(query: String) async throws -> [TransitStop]
    func getDepartures(stopId: String) async throws -> [Departure]
}
```

Implementations:

- V0: `StaticGtfsTransitRepository`
- V1: `OneBusAwayTransitRepository`

The UI does not know which implementation is being used.

## Persistence

TransitBar uses `UserDefaults`.

Persisted values:

- Favorite stops
- Primary stop
- Refresh interval
- Launch at login preference

SwiftData and Core Data are intentionally not used.

## Data Models

`FavoriteStop`

- `stopId`
- `stopName`
- `label` optional

`Departure`

- `routeName`
- `destination`
- `departureTime`

`StopLabel`

- `home`
- `work`

V0 and V1 may ignore labels, but the model supports them for V2.

## Primary Stop

Users may save multiple favorite stops. One stop is designated as the Primary Stop.

Menu bar text is derived from departures at the Primary Stop. This prevents the menu bar title from changing unpredictably.

Example:

- Primary Stop: Bellevue Downtown Station
- Menu Bar: `2 Line 8m`

## Favorite Stop Management

Users can:

- Search stops
- Add favorites
- Remove favorites
- Set primary stop

## User Interface

### Menu Bar

Display:

- Route name + minutes until departure

Examples:

- `2 Line 8m`
- `550 5m`

The menu bar should not display only a countdown.

### Dropdown

Display departures grouped by favorite stop.

Example:

```text
Bellevue Downtown Station

2 Line -> Redmond      8m
2 Line -> Redmond     18m

South Bellevue Station

2 Line -> Seattle      6m
2 Line -> Seattle     16m
```

### Favorites Window

Separate window opened from:

- Add Favorite Stop
- Manage Favorites

Capabilities:

- Search stops
- Add favorite
- Remove favorite
- Set primary stop

## GTFS Requirements

Required files:

- `stops.txt`
- `routes.txt`
- `trips.txt`
- `stop_times.txt`
- `calendar.txt`
- `calendar_dates.txt`

TransitBar supports GTFS times greater than 24:00, including:

- `24:15:00`
- `25:30:00`
- `26:05:00`

## Refresh Behavior

### V0

No network calls.

Departures are recalculated every 60 seconds and refreshed on:

- App launch
- Menu open
- Timer

### V1

Default refresh interval:

- 30 seconds

User selectable values:

- 15 seconds
- 30 seconds recommended
- 60 seconds
- 120 seconds

Refresh on:

- App launch
- Menu open
- System wake
- Network reconnect
- Scheduled interval

## Error States

- No favorites: `Add a favorite stop to get started.`
- No departures: `No upcoming departures.`
- Data failure: `Unable to load departures.`

## Current Implementation

V0 is implemented as a macOS SwiftUI `MenuBarExtra` app with:

- MVVM + Repository architecture
- `StaticGtfsTransitRepository`
- Bundle-backed GTFS parsing
- Stop search
- Favorite add/remove
- Primary stop selection
- Grouped dropdown departures
- Menu bar primary departure text
- `UserDefaults` persistence
- 60 second refresh timer

The sample GTFS feed lives at `TransitBar/Resources/GTFS`. Replace those files with a real feed to use live schedule data for a specific agency.
