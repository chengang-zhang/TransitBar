//
//  TransitBarTests.swift
//  TransitBarTests
//
//  Created by Chengang Zhang on 6/5/26.
//

import Testing
import Foundation
@testable import TransitBar

struct TransitBarTests {

    @Test func oneBusAwayAPIKeyProviderPrefersUserDefaults() {
        let suiteName = "TransitBarTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set("defaults-key", forKey: OneBusAwayAPIKeyProvider.userDefaultsKey)

        let apiKey = OneBusAwayAPIKeyProvider.apiKey(
            userDefaults: userDefaults,
            environment: [OneBusAwayAPIKeyProvider.environmentKey: "environment-key"]
        )

        #expect(apiKey == "defaults-key")
    }

    @Test func oneBusAwayAPIKeyProviderFallsBackToEnvironment() {
        let suiteName = "TransitBarTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let apiKey = OneBusAwayAPIKeyProvider.apiKey(
            userDefaults: userDefaults,
            environment: [OneBusAwayAPIKeyProvider.environmentKey: "environment-key"]
        )

        #expect(apiKey == "environment-key")
    }

    @Test func oneBusAwayDecodesPredictedArrivalResponse() throws {
        let json = """
        {
          "code": 200,
          "text": "OK",
          "currentTime": 1710959349232,
          "data": {
            "entry": {
              "arrivalsAndDepartures": [
                {
                  "routeId": "1_100259",
                  "routeShortName": "67",
                  "tripHeadsign": "Northgate Station Roosevelt Station",
                  "tripId": "1_534487075",
                  "stopId": "1_75403",
                  "predicted": true,
                  "predictedDepartureTime": 1710959461000,
                  "scheduledDepartureTime": 1710959220000,
                  "status": "default"
                }
              ]
            },
            "references": {
              "routes": [
                {
                  "id": "1_100259",
                  "agencyId": "1",
                  "shortName": "67",
                  "longName": "",
                  "description": "Northgate - Roosevelt - University District",
                  "type": 3
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            OneBusAwayEntryResponse<OneBusAwayArrivalsAndDeparturesForStop>.self,
            from: Data(json.utf8)
        )

        let arrival = try #require(response.data.entry.arrivalsAndDepartures.first)
        #expect(response.code == 200)
        #expect(arrival.routeDisplayName == "67")
        #expect(arrival.bestDepartureTimeMilliseconds == 1_710_959_461_000)
        #expect(response.data.references?.routesById["1_100259"]?.description == "Northgate - Roosevelt - University District")
    }

    @Test func oneBusAwayIgnoresZeroTimestampPlaceholders() throws {
        let json = """
        {
          "code": 200,
          "text": "OK",
          "data": {
            "entry": {
              "arrivalsAndDepartures": [
                {
                  "routeId": "40_2LINE",
                  "routeShortName": "2 Line",
                  "tripHeadsign": "Lynnwood City Center",
                  "tripId": "40_trip",
                  "stopId": "40_E27-T1",
                  "predicted": false,
                  "predictedDepartureTime": 0,
                  "predictedArrivalTime": 0,
                  "scheduledDepartureTime": 1780956480000,
                  "scheduledArrivalTime": 1780956450000,
                  "status": "default"
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            OneBusAwayEntryResponse<OneBusAwayArrivalsAndDeparturesForStop>.self,
            from: Data(json.utf8)
        )

        let arrival = try #require(response.data.entry.arrivalsAndDepartures.first)
        #expect(arrival.bestDepartureTimeMilliseconds == 1_780_956_480_000)
        #expect(arrival.scheduledTimeMilliseconds == 1_780_956_480_000)
    }

    @Test func oneBusAwayReferencesTolerateDuplicateStopIds() throws {
        let json = """
        {
          "code": 200,
          "text": "OK",
          "data": {
            "entry": {
              "stopIds": ["40_C03"]
            },
            "references": {
              "stops": [
                { "id": "40_C03", "name": "Judkins Park", "code": "C03", "direction": "E" },
                { "id": "40_C03", "name": "Judkins Park", "code": "C03", "direction": "W" }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            OneBusAwayEntryResponse<OneBusAwayStopsForRoute>.self,
            from: Data(json.utf8)
        )

        #expect(response.data.references?.stopsById["40_C03"]?.name == "Judkins Park")
    }

    @Test func oneBusAwayRouteStopsPreferOrderedDirectionGrouping() throws {
        let json = """
        {
          "code": 200,
          "text": "OK",
          "data": {
            "entry": {
              "routeId": "40_2LINE",
              "stopIds": ["40_1108", "40_N23-T2", "40_E31-T1"],
              "stopGroupings": [
                {
                  "type": "direction",
                  "ordered": true,
                  "stopGroups": [
                    {
                      "id": "0",
                      "name": {
                        "name": "Downtown Redmond",
                        "names": ["Downtown Redmond"],
                        "type": "destination"
                      },
                      "stopIds": ["40_N23-T2", "40_N19-T2", "40_E31-T1", "40_N23-T2"]
                    }
                  ]
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            OneBusAwayEntryResponse<OneBusAwayStopsForRoute>.self,
            from: Data(json.utf8)
        )

        #expect(response.data.entry.orderedStopIds == ["40_N23-T2", "40_N19-T2", "40_E31-T1"])
    }

    @MainActor
    @Test func gtfsTimeSupportsHoursPastMidnight() {
        #expect(GTFSTime.seconds(from: "24:15:00") == 87_300)
        #expect(GTFSTime.seconds(from: "25:30:00") == 91_800)
        #expect(GTFSTime.seconds(from: "26:05:00") == 93_900)
    }

    @Test func realtimeOverlayUsesExactTimestampUpdate() {
        let scheduled = Date(timeIntervalSince1970: 1_800)
        let predicted = Date(timeIntervalSince1970: 1_950)
        let departure = testDeparture(scheduled: scheduled)
        let update = RealtimeTripUpdate(
            tripId: "trip",
            stopTimeUpdates: [
                RealtimeStopTimeUpdate(stopId: "stop", arrivalTime: predicted)
            ]
        )

        let departures = RealtimeArrivalOverlayService().overlay(
            staticDepartures: [departure],
            tripUpdates: [update]
        )

        #expect(departures.first?.departureTime == predicted)
        #expect(departures.first?.scheduledTime == scheduled)
        #expect(departures.first?.predictionSource == .realtime)
    }

    @Test func realtimeOverlayAppliesDelayOnlyUpdate() {
        let scheduled = Date(timeIntervalSince1970: 1_800)
        let departure = testDeparture(scheduled: scheduled)
        let update = RealtimeTripUpdate(
            tripId: "trip",
            stopTimeUpdates: [
                RealtimeStopTimeUpdate(stopId: "stop", arrivalDelay: 120)
            ]
        )

        let departures = RealtimeArrivalOverlayService().overlay(
            staticDepartures: [departure],
            tripUpdates: [update]
        )

        #expect(departures.first?.departureTime == scheduled.addingTimeInterval(120))
        #expect(departures.first?.predictionSource == .realtime)
    }

    @Test func realtimeOverlayMarksOnTimeUpdateAsRealtime() {
        let scheduled = Date(timeIntervalSince1970: 1_800)
        let departure = testDeparture(scheduled: scheduled)
        let update = RealtimeTripUpdate(
            tripId: "trip",
            stopTimeUpdates: [
                RealtimeStopTimeUpdate(stopId: "stop", arrivalTime: scheduled)
            ]
        )

        let departures = RealtimeArrivalOverlayService().overlay(
            staticDepartures: [departure],
            tripUpdates: [update]
        )

        #expect(departures.first?.departureTime == scheduled)
        #expect(departures.first?.predictionSource == .realtime)
    }

    @Test func realtimeOverlayFallsBackWhenNoRealtimeMatchExists() {
        let scheduled = Date(timeIntervalSince1970: 1_800)
        let departure = testDeparture(scheduled: scheduled)
        let update = RealtimeTripUpdate(
            tripId: "other-trip",
            stopTimeUpdates: [
                RealtimeStopTimeUpdate(stopId: "stop", arrivalDelay: 120)
            ]
        )

        let departures = RealtimeArrivalOverlayService().overlay(
            staticDepartures: [departure],
            tripUpdates: [update]
        )

        #expect(departures.first?.departureTime == scheduled)
        #expect(departures.first?.predictionSource == .scheduled)
    }

    @Test func realtimeOverlayMarksCanceledTrip() {
        let departure = testDeparture(scheduled: Date(timeIntervalSince1970: 1_800))
        let update = RealtimeTripUpdate(
            tripId: "trip",
            scheduleRelationship: .canceled,
            stopTimeUpdates: [
                RealtimeStopTimeUpdate(stopId: "stop")
            ]
        )

        let departures = RealtimeArrivalOverlayService().overlay(
            staticDepartures: [departure],
            tripUpdates: [update]
        )

        #expect(departures.first?.predictionSource == .canceled)
        #expect(departures.first?.isCanceled == true)
    }

    @Test func realtimeOverlayMarksSkippedStop() {
        let departure = testDeparture(scheduled: Date(timeIntervalSince1970: 1_800))
        let update = RealtimeTripUpdate(
            tripId: "trip",
            stopTimeUpdates: [
                RealtimeStopTimeUpdate(stopId: "stop", scheduleRelationship: .skipped)
            ]
        )

        let departures = RealtimeArrivalOverlayService().overlay(
            staticDepartures: [departure],
            tripUpdates: [update]
        )

        #expect(departures.first?.predictionSource == .skipped)
        #expect(departures.first?.isCanceled == true)
    }

    @Test func realtimeArrivalServiceFallsBackToStaticDeparturesWhenProviderFails() async throws {
        let scheduled = Date(timeIntervalSince1970: 1_800)
        let departure = testDeparture(scheduled: scheduled)
        let service = RealtimeOverlayArrivalService(
            staticArrivalService: MockArrivalService(departures: [departure]),
            realtimeProvider: MockRealtimeProvider(error: TestRealtimeError.fetchFailed)
        )

        let departures = try await service.getDepartures(stopId: "stop")

        #expect(departures == [departure])
    }

    @Test func realtimeAlertMatcherMatchesNamespacedStopId() {
        let alert = RealtimeAlert(
            id: "alert",
            routeIds: [],
            stopIds: ["990002"],
            headerText: "Station alert",
            descriptionText: nil
        )

        let matches = RealtimeAlertMatchingService().matching(
            alerts: [alert],
            stopId: "puget-sound:990002",
            departures: []
        )

        #expect(matches == [alert])
    }

    @Test func realtimeAlertMatcherMatchesNamespacedRouteIdFromDeparture() {
        let departure = Departure(
            tripId: "trip",
            stopId: "puget-sound:990002",
            routeId: "puget-sound:100479",
            routeName: "1",
            destination: "Lynnwood",
            departureTime: Date(timeIntervalSince1970: 1_800),
            routeType: 0
        )
        let alert = RealtimeAlert(
            id: "alert",
            routeIds: ["100479"],
            stopIds: [],
            headerText: "Route alert",
            descriptionText: nil
        )

        let matches = RealtimeAlertMatchingService().matching(
            alerts: [alert],
            stopId: "puget-sound:990002",
            departures: [departure]
        )

        #expect(matches == [alert])
    }

    @Test func compositeRealtimeProviderCombinesSuccessfulProviders() async throws {
        let soundTransitUpdate = RealtimeTripUpdate(tripId: "st-trip", stopTimeUpdates: [])
        let metroUpdate = RealtimeTripUpdate(tripId: "metro-trip", stopTimeUpdates: [])
        let provider = CompositeRealtimeProvider(providers: [
            MockRealtimeProvider(tripUpdates: [soundTransitUpdate]),
            MockRealtimeProvider(tripUpdates: [metroUpdate])
        ])

        let updates = try await provider.tripUpdates()

        #expect(updates == [soundTransitUpdate, metroUpdate])
    }

    @Test func compositeRealtimeProviderKeepsSuccessfulProviderWhenAnotherFails() async throws {
        let metroUpdate = RealtimeTripUpdate(tripId: "metro-trip", stopTimeUpdates: [])
        let provider = CompositeRealtimeProvider(providers: [
            MockRealtimeProvider(error: TestRealtimeError.fetchFailed),
            MockRealtimeProvider(tripUpdates: [metroUpdate])
        ])

        let updates = try await provider.tripUpdates()

        #expect(updates == [metroUpdate])
    }

    @Test func compositeRealtimeProviderReturnsEmptyWhenFeedsAreSuccessfullyEmpty() async throws {
        let provider = CompositeRealtimeProvider(providers: [
            MockRealtimeProvider(),
            MockRealtimeProvider()
        ])

        let updates = try await provider.tripUpdates()

        #expect(updates.isEmpty)
    }

    @MainActor
    @Test func parserReadsSplitStopTimesWhenPlainFileIsMissing() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        func write(_ filename: String, _ text: String) throws {
            try text.write(to: directoryURL.appendingPathComponent(filename), atomically: true, encoding: .utf8)
        }

        try write("agency.txt", "agency_id,agency_name\nagency,Test Agency\n")
        try write("stops.txt", "stop_id,stop_name\nstop-a,Stop A\nstop-b,Stop B\n")
        try write("routes.txt", "route_id,agency_id,route_short_name,route_long_name,route_type\nroute,agency,10,Route 10,3\n")
        try write("trips.txt", "route_id,service_id,trip_id,trip_headsign\nroute,daily,trip,Stop B\n")
        try write("calendar.txt", "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\ndaily,1,1,1,1,1,1,1,20260101,20261231\n")
        try write("calendar_dates.txt", "service_id,date,exception_type\n")
        try write("stop_times.txt.part00", "trip_id,stop_id,departure_time,stop_sequence\ntrip,stop-a,08:00:00,1\n")
        try write("stop_times.txt.part01", "trip,stop-b,08:10:00,2\n")

        let schedule = try GTFSParser().parse(directoryURL: directoryURL, feedId: "test", feedName: "Test Feed")

        #expect(schedule.stopTimesByTripId["test:trip"]?.map(\.stopId) == ["test:stop-a", "test:stop-b"])
        #expect(schedule.stopTimesByStopId["test:stop-a"]?.first?.departureSeconds == 28_800)
    }

    @MainActor
    @Test func repositoryFindsLateNightDepartureFromPreviousServiceDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let serviceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 1, minute: 10))!
        let expectedDeparture = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 1, minute: 30))!

        let schedule = GTFSSchedule(
            stops: [
                "stop": GTFSStop(
                    id: "stop",
                    code: "100",
                    name: "Test Stop",
                    description: "Test Stop to Redmond",
                    locationType: nil,
                    parentStation: "station",
                    platformCode: "1",
                    feedName: "Test Feed"
                )
            ],
            routes: [
                "route": GTFSRoute(
                    id: "route",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "2 Line",
                    longName: "Link",
                    routeDescription: "",
                    routeType: 0,
                    colorHex: "007CAD",
                    textColorHex: "FFFFFF"
                )
            ],
            trips: ["trip": GTFSTrip(id: "trip", routeId: "route", serviceId: "daily", headsign: "Redmond")],
            calendars: [
                "daily": GTFSCalendar(
                    serviceId: "daily",
                    activeWeekdays: Set(1...7),
                    startDate: serviceDate,
                    endDate: serviceDate
                )
            ],
            calendarDates: [:],
            stopTimesByStopId: [
                "stop": [
                    GTFSStopTime(
                        tripId: "trip",
                        stopId: "stop",
                        departureSeconds: GTFSTime.seconds(from: "25:30:00")!,
                        sequence: 1
                    )
                ]
            ],
            stopTimesByTripId: [
                "trip": [
                    GTFSStopTime(
                        tripId: "trip",
                        stopId: "stop",
                        departureSeconds: GTFSTime.seconds(from: "25:30:00")!,
                        sequence: 1
                    )
                ]
            ]
        )

        let repository = StaticGtfsTransitRepository(schedule: schedule, calendar: calendar)
        let departures = repository.upcomingDepartures(stopId: "stop", at: now)

        #expect(departures.count == 1)
        #expect(departures.first?.routeName == "2 Line")
        #expect(departures.first?.destination == "Redmond")
        #expect(departures.first?.departureTime == expectedDeparture)
    }

    @MainActor
    @Test func repositoryFallsBackToNextDepartureWhenNormalWindowIsEmpty() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let serviceStart = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        let serviceEnd = calendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 1, minute: 55))!
        let expectedDeparture = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 8, minute: 10))!

        let schedule = GTFSSchedule(
            stops: [
                "stop": GTFSStop(
                    id: "stop",
                    code: "100",
                    name: "Test Stop",
                    description: "Test Stop to Lynnwood",
                    locationType: nil,
                    parentStation: "station",
                    platformCode: "1",
                    feedName: "Test Feed"
                )
            ],
            routes: [
                "route": GTFSRoute(
                    id: "route",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "2 Line",
                    longName: "Link",
                    routeDescription: "",
                    routeType: 0,
                    colorHex: "007CAD",
                    textColorHex: "FFFFFF"
                )
            ],
            trips: ["morning-trip": GTFSTrip(id: "morning-trip", routeId: "route", serviceId: "daily", headsign: "Lynnwood")],
            calendars: [
                "daily": GTFSCalendar(
                    serviceId: "daily",
                    activeWeekdays: Set(1...7),
                    startDate: serviceStart,
                    endDate: serviceEnd
                )
            ],
            calendarDates: [:],
            stopTimesByStopId: [
                "stop": [
                    GTFSStopTime(
                        tripId: "morning-trip",
                        stopId: "stop",
                        departureSeconds: GTFSTime.seconds(from: "08:10:00")!,
                        sequence: 1
                    )
                ]
            ],
            stopTimesByTripId: [
                "morning-trip": [
                    GTFSStopTime(
                        tripId: "morning-trip",
                        stopId: "stop",
                        departureSeconds: GTFSTime.seconds(from: "08:10:00")!,
                        sequence: 1
                    )
                ]
            ]
        )

        let repository = StaticGtfsTransitRepository(schedule: schedule, calendar: calendar)
        let departures = repository.upcomingDepartures(stopId: "stop", at: now)

        #expect(departures.count == 1)
        #expect(departures.first?.routeName == "2 Line")
        #expect(departures.first?.destination == "Lynnwood")
        #expect(departures.first?.departureTime == expectedDeparture)
    }

    @MainActor
    @Test func repositoryFiltersLineSearchByRouteTypeAndReturnsStops() async throws {
        let schedule = GTFSSchedule(
            stops: [
                "rail-stop": GTFSStop(
                    id: "rail-stop",
                    code: "200",
                    name: "Test Station",
                    description: "",
                    locationType: 0,
                    parentStation: "",
                    platformCode: "",
                    feedName: "Test Feed"
                ),
                "bus-stop": GTFSStop(
                    id: "bus-stop",
                    code: "300",
                    name: "Test Station",
                    description: "",
                    locationType: 0,
                    parentStation: "",
                    platformCode: "",
                    feedName: "Test Feed"
                )
            ],
            routes: [
                "rail-route": GTFSRoute(
                    id: "rail-route",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "2 Line",
                    longName: "Link",
                    routeDescription: "",
                    routeType: 0,
                    colorHex: "007CAD",
                    textColorHex: "FFFFFF"
                ),
                "bus-route": GTFSRoute(
                    id: "bus-route",
                    feedId: "king-county",
                    feedName: "King County",
                    shortName: "255",
                    longName: "Bus",
                    routeDescription: "Totem Lake TC-Kirkland TC-UW Link Sta-Univ Dist",
                    routeType: 3,
                    colorHex: "FDB71A",
                    textColorHex: "000000"
                ),
                "duplicate-bus-route": GTFSRoute(
                    id: "duplicate-bus-route",
                    feedId: "king-county",
                    feedName: "King County",
                    shortName: "255",
                    longName: "Bus",
                    routeDescription: "Totem Lake TC-Kirkland TC-UW Link Sta-Univ Dist",
                    routeType: 3,
                    colorHex: "FDB71A",
                    textColorHex: "000000"
                ),
                "replacement-shuttle": GTFSRoute(
                    id: "replacement-shuttle",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "Shuttle",
                    longName: "2 Line Shuttle Bus",
                    routeDescription: "",
                    routeType: 3,
                    colorHex: "FFB819",
                    textColorHex: "000000"
                ),
                "ferry-route": GTFSRoute(
                    id: "ferry-route",
                    feedId: "puget-sound",
                    feedName: "Washington State Ferries",
                    shortName: "",
                    longName: "Seattle - Bainbridge Island",
                    routeDescription: "",
                    routeType: 4,
                    colorHex: "",
                    textColorHex: ""
                )
            ],
            trips: [
                "rail-trip": GTFSTrip(id: "rail-trip", routeId: "rail-route", serviceId: "daily", headsign: "Redmond"),
                "bus-trip": GTFSTrip(id: "bus-trip", routeId: "bus-route", serviceId: "daily", headsign: "Kirkland")
            ],
            calendars: [:],
            calendarDates: [:],
            stopTimesByStopId: [
                "rail-stop": [GTFSStopTime(tripId: "rail-trip", stopId: "rail-stop", departureSeconds: 3600, sequence: 1)],
                "bus-stop": [GTFSStopTime(tripId: "bus-trip", stopId: "bus-stop", departureSeconds: 3600, sequence: 1)]
            ],
            stopTimesByTripId: [
                "rail-trip": [GTFSStopTime(tripId: "rail-trip", stopId: "rail-stop", departureSeconds: 3600, sequence: 1)],
                "bus-trip": [GTFSStopTime(tripId: "bus-trip", stopId: "bus-stop", departureSeconds: 3600, sequence: 1)]
            ]
        )

        let repository = StaticGtfsTransitRepository(schedule: schedule)

        let railResults = try await repository.searchLines(query: "2", filter: .rail)
        let busResults = try await repository.searchLines(query: "255", filter: .bus)
        let ferryResults = try await repository.searchLines(query: "Bainbridge", filter: .ferry)
        let allResults = try await repository.searchLines(query: "", filter: .all)
        let shuttleResults = try await repository.searchLines(query: "Shuttle", filter: .bus)
        let railStops = try await repository.getStops(lineId: "rail-route")

        #expect(railResults.map(\.id) == ["rail-route"])
        #expect(busResults.map(\.id) == ["bus-route"])
        #expect(ferryResults.map(\.id) == ["ferry-route"])
        #expect(allResults.map(\.id) == ["rail-route", "bus-route", "replacement-shuttle", "ferry-route"])
        #expect(shuttleResults.map(\.id) == ["replacement-shuttle"])
        #expect(railStops.map(\.id) == ["rail-stop"])
    }

    @MainActor
    @Test func repositoryOrdersStopsUsingRepresentativeTripPattern() async throws {
        let stops = [
            "stop-a": GTFSStop(id: "stop-a", code: "", name: "A Station", description: "", locationType: 0, parentStation: "", platformCode: "", feedName: "Test Feed"),
            "stop-b": GTFSStop(id: "stop-b", code: "", name: "B Station", description: "", locationType: 0, parentStation: "", platformCode: "", feedName: "Test Feed"),
            "stop-c": GTFSStop(id: "stop-c", code: "", name: "C Station", description: "", locationType: 0, parentStation: "", platformCode: "", feedName: "Test Feed")
        ]

        let schedule = GTFSSchedule(
            stops: stops,
            routes: [
                "route": GTFSRoute(
                    id: "route",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "2 Line",
                    longName: "Link",
                    routeDescription: "",
                    routeType: 0,
                    colorHex: "007CAD",
                    textColorHex: "FFFFFF"
                )
            ],
            trips: [
                "trip-1": GTFSTrip(id: "trip-1", routeId: "route", serviceId: "daily", headsign: "Downtown"),
                "trip-2": GTFSTrip(id: "trip-2", routeId: "route", serviceId: "daily", headsign: "Downtown"),
                "trip-3": GTFSTrip(id: "trip-3", routeId: "route", serviceId: "daily", headsign: "Downtown")
            ],
            calendars: [:],
            calendarDates: [:],
            stopTimesByStopId: [
                "stop-a": [
                    GTFSStopTime(tripId: "trip-1", stopId: "stop-a", departureSeconds: 3600, sequence: 1),
                    GTFSStopTime(tripId: "trip-2", stopId: "stop-a", departureSeconds: 3600, sequence: 1),
                    GTFSStopTime(tripId: "trip-3", stopId: "stop-a", departureSeconds: 3900, sequence: 1)
                ],
                "stop-b": [
                    GTFSStopTime(tripId: "trip-1", stopId: "stop-b", departureSeconds: 3800, sequence: 3),
                    GTFSStopTime(tripId: "trip-2", stopId: "stop-b", departureSeconds: 3650, sequence: 2),
                    GTFSStopTime(tripId: "trip-3", stopId: "stop-b", departureSeconds: 4100, sequence: 3)
                ],
                "stop-c": [
                    GTFSStopTime(tripId: "trip-1", stopId: "stop-c", departureSeconds: 3700, sequence: 2),
                    GTFSStopTime(tripId: "trip-2", stopId: "stop-c", departureSeconds: 3800, sequence: 3),
                    GTFSStopTime(tripId: "trip-3", stopId: "stop-c", departureSeconds: 4000, sequence: 2)
                ]
            ],
            stopTimesByTripId: [
                "trip-1": [
                    GTFSStopTime(tripId: "trip-1", stopId: "stop-a", departureSeconds: 3600, sequence: 1),
                    GTFSStopTime(tripId: "trip-1", stopId: "stop-c", departureSeconds: 3700, sequence: 2),
                    GTFSStopTime(tripId: "trip-1", stopId: "stop-b", departureSeconds: 3800, sequence: 3)
                ],
                "trip-2": [
                    GTFSStopTime(tripId: "trip-2", stopId: "stop-a", departureSeconds: 3600, sequence: 1),
                    GTFSStopTime(tripId: "trip-2", stopId: "stop-b", departureSeconds: 3650, sequence: 2),
                    GTFSStopTime(tripId: "trip-2", stopId: "stop-c", departureSeconds: 3800, sequence: 3)
                ],
                "trip-3": [
                    GTFSStopTime(tripId: "trip-3", stopId: "stop-a", departureSeconds: 3900, sequence: 1),
                    GTFSStopTime(tripId: "trip-3", stopId: "stop-c", departureSeconds: 4000, sequence: 2),
                    GTFSStopTime(tripId: "trip-3", stopId: "stop-b", departureSeconds: 4100, sequence: 3)
                ]
            ]
        )

        let repository = StaticGtfsTransitRepository(schedule: schedule)
        let routeStops = try await repository.getStops(lineId: "route")

        #expect(routeStops.map(\.id) == ["stop-a", "stop-c", "stop-b"])
    }

    @MainActor
    @Test func repositoryPrefersCompleteStopPatternOverMoreFrequentShortPattern() async throws {
        let stops = [
            "terminal-a": GTFSStop(id: "terminal-a", code: "", name: "Terminal A", description: "", locationType: 0, parentStation: "", platformCode: "", feedName: "Test Feed"),
            "middle": GTFSStop(id: "middle", code: "", name: "Middle", description: "", locationType: 0, parentStation: "", platformCode: "", feedName: "Test Feed"),
            "terminal-b": GTFSStop(id: "terminal-b", code: "", name: "Terminal B", description: "", locationType: 0, parentStation: "", platformCode: "", feedName: "Test Feed")
        ]

        let schedule = GTFSSchedule(
            stops: stops,
            routes: [
                "route": GTFSRoute(
                    id: "route",
                    feedId: "sound-transit",
                    feedName: "Sound Transit",
                    shortName: "1 Line",
                    longName: "Terminal A - Terminal B",
                    routeDescription: "",
                    routeType: 0,
                    colorHex: "28813F",
                    textColorHex: "FFFFFF"
                )
            ],
            trips: [
                "complete-trip": GTFSTrip(id: "complete-trip", routeId: "route", serviceId: "daily", headsign: "Terminal B"),
                "short-trip-1": GTFSTrip(id: "short-trip-1", routeId: "route", serviceId: "daily", headsign: "Middle"),
                "short-trip-2": GTFSTrip(id: "short-trip-2", routeId: "route", serviceId: "daily", headsign: "Middle")
            ],
            calendars: [:],
            calendarDates: [:],
            stopTimesByStopId: [
                "terminal-a": [
                    GTFSStopTime(tripId: "complete-trip", stopId: "terminal-a", departureSeconds: 3600, sequence: 1),
                    GTFSStopTime(tripId: "short-trip-1", stopId: "terminal-a", departureSeconds: 3700, sequence: 1),
                    GTFSStopTime(tripId: "short-trip-2", stopId: "terminal-a", departureSeconds: 3800, sequence: 1)
                ],
                "middle": [
                    GTFSStopTime(tripId: "complete-trip", stopId: "middle", departureSeconds: 3700, sequence: 2),
                    GTFSStopTime(tripId: "short-trip-1", stopId: "middle", departureSeconds: 3800, sequence: 2),
                    GTFSStopTime(tripId: "short-trip-2", stopId: "middle", departureSeconds: 3900, sequence: 2)
                ],
                "terminal-b": [
                    GTFSStopTime(tripId: "complete-trip", stopId: "terminal-b", departureSeconds: 3800, sequence: 3)
                ]
            ],
            stopTimesByTripId: [
                "complete-trip": [
                    GTFSStopTime(tripId: "complete-trip", stopId: "terminal-a", departureSeconds: 3600, sequence: 1),
                    GTFSStopTime(tripId: "complete-trip", stopId: "middle", departureSeconds: 3700, sequence: 2),
                    GTFSStopTime(tripId: "complete-trip", stopId: "terminal-b", departureSeconds: 3800, sequence: 3)
                ],
                "short-trip-1": [
                    GTFSStopTime(tripId: "short-trip-1", stopId: "terminal-a", departureSeconds: 3700, sequence: 1),
                    GTFSStopTime(tripId: "short-trip-1", stopId: "middle", departureSeconds: 3800, sequence: 2)
                ],
                "short-trip-2": [
                    GTFSStopTime(tripId: "short-trip-2", stopId: "terminal-a", departureSeconds: 3800, sequence: 1),
                    GTFSStopTime(tripId: "short-trip-2", stopId: "middle", departureSeconds: 3900, sequence: 2)
                ]
            ]
        )

        let repository = StaticGtfsTransitRepository(schedule: schedule)
        let routeStops = try await repository.getStops(lineId: "route")

        #expect(routeStops.map(\.id) == ["terminal-a", "middle", "terminal-b"])
    }

}

private func testDeparture(scheduled: Date) -> Departure {
    Departure(
        id: "trip-stop-\(Int(scheduled.timeIntervalSince1970))",
        tripId: "trip",
        stopId: "stop",
        routeId: "route",
        routeName: "2",
        destination: "Downtown Redmond",
        departureTime: scheduled,
        scheduledTime: scheduled,
        routeType: 0
    )
}

private struct MockArrivalService: ArrivalService {
    let departures: [Departure]

    func getDepartures(stopId: String) async throws -> [Departure] {
        departures
    }
}

private struct MockRealtimeProvider: RealtimeProvider {
    let tripUpdates: [RealtimeTripUpdate]
    let error: Error?

    init(tripUpdates: [RealtimeTripUpdate] = [], error: Error? = nil) {
        self.tripUpdates = tripUpdates
        self.error = error
    }

    func tripUpdates() async throws -> [RealtimeTripUpdate] {
        if let error {
            throw error
        }
        return tripUpdates
    }

    func alerts() async throws -> [RealtimeAlert] {
        []
    }

    func vehiclePositions() async throws -> [RealtimeVehiclePosition] {
        []
    }
}

private enum TestRealtimeError: Error {
    case fetchFailed
}
