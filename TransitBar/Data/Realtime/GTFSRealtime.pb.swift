// Minimal SwiftProtobuf model surface for the official GTFS-Realtime schema.
// It covers the feed fields TransitBar consumes: trip updates, alerts, and
// a vehicle-position stub.

import SwiftProtobuf

fileprivate nonisolated struct TransitRealtime_ProtobufVersionCheck: SwiftProtobuf.ProtobufAPIVersionCheck {
    struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
    typealias Version = _2
}

nonisolated struct TransitRealtime_FeedMessage {
    private var _header: TransitRealtime_FeedHeader?
    var entity: [TransitRealtime_FeedEntity] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var header: TransitRealtime_FeedHeader {
        get { _header ?? TransitRealtime_FeedHeader() }
        set { _header = newValue }
    }
    var hasHeader: Bool { _header != nil }
    mutating func clearHeader() { _header = nil }

    init() {}
}

nonisolated struct TransitRealtime_FeedHeader {
    nonisolated enum Incrementality: SwiftProtobuf.Enum {
        typealias RawValue = Int

        case fullDataset
        case differential
        case UNRECOGNIZED(Int)

        init() { self = .fullDataset }

        init?(rawValue: Int) {
            switch rawValue {
            case 0: self = .fullDataset
            case 1: self = .differential
            default: self = .UNRECOGNIZED(rawValue)
            }
        }

        var rawValue: Int {
            switch self {
            case .fullDataset: return 0
            case .differential: return 1
            case .UNRECOGNIZED(let value): return value
            }
        }
    }

    private var _gtfsRealtimeVersion: String?
    private var _incrementality: Incrementality?
    private var _timestamp: UInt64?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var gtfsRealtimeVersion: String {
        get { _gtfsRealtimeVersion ?? "" }
        set { _gtfsRealtimeVersion = newValue }
    }
    var hasGtfsRealtimeVersion: Bool { _gtfsRealtimeVersion != nil }
    mutating func clearGtfsRealtimeVersion() { _gtfsRealtimeVersion = nil }

    var incrementality: Incrementality {
        get { _incrementality ?? .fullDataset }
        set { _incrementality = newValue }
    }
    var hasIncrementality: Bool { _incrementality != nil }
    mutating func clearIncrementality() { _incrementality = nil }

    var timestamp: UInt64 {
        get { _timestamp ?? 0 }
        set { _timestamp = newValue }
    }
    var hasTimestamp: Bool { _timestamp != nil }
    mutating func clearTimestamp() { _timestamp = nil }

    init() {}
}

nonisolated struct TransitRealtime_FeedEntity {
    private var _id: String?
    private var _isDeleted: Bool?
    private var _tripUpdate: TransitRealtime_TripUpdate?
    private var _vehicle: TransitRealtime_VehiclePosition?
    private var _alert: TransitRealtime_Alert?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var id: String {
        get { _id ?? "" }
        set { _id = newValue }
    }
    var hasID: Bool { _id != nil }
    mutating func clearID() { _id = nil }

    var isDeleted: Bool {
        get { _isDeleted ?? false }
        set { _isDeleted = newValue }
    }
    var hasIsDeleted: Bool { _isDeleted != nil }
    mutating func clearIsDeleted() { _isDeleted = nil }

    var tripUpdate: TransitRealtime_TripUpdate {
        get { _tripUpdate ?? TransitRealtime_TripUpdate() }
        set { _tripUpdate = newValue }
    }
    var hasTripUpdate: Bool { _tripUpdate != nil }
    mutating func clearTripUpdate() { _tripUpdate = nil }

    var vehicle: TransitRealtime_VehiclePosition {
        get { _vehicle ?? TransitRealtime_VehiclePosition() }
        set { _vehicle = newValue }
    }
    var hasVehicle: Bool { _vehicle != nil }
    mutating func clearVehicle() { _vehicle = nil }

    var alert: TransitRealtime_Alert {
        get { _alert ?? TransitRealtime_Alert() }
        set { _alert = newValue }
    }
    var hasAlert: Bool { _alert != nil }
    mutating func clearAlert() { _alert = nil }

    init() {}
}

nonisolated struct TransitRealtime_TripUpdate {
    nonisolated struct StopTimeEvent {
        private var _delay: Int32?
        private var _time: Int64?
        private var _uncertainty: Int32?
        var unknownFields = SwiftProtobuf.UnknownStorage()

        var delay: Int32 {
            get { _delay ?? 0 }
            set { _delay = newValue }
        }
        var hasDelay: Bool { _delay != nil }
        mutating func clearDelay() { _delay = nil }

        var time: Int64 {
            get { _time ?? 0 }
            set { _time = newValue }
        }
        var hasTime: Bool { _time != nil }
        mutating func clearTime() { _time = nil }

        var uncertainty: Int32 {
            get { _uncertainty ?? 0 }
            set { _uncertainty = newValue }
        }
        var hasUncertainty: Bool { _uncertainty != nil }
        mutating func clearUncertainty() { _uncertainty = nil }

        init() {}
    }

    nonisolated struct StopTimeUpdate {
        nonisolated enum ScheduleRelationship: SwiftProtobuf.Enum {
            typealias RawValue = Int

            case scheduled
            case skipped
            case noData
            case UNRECOGNIZED(Int)

            init() { self = .scheduled }

            init?(rawValue: Int) {
                switch rawValue {
                case 0: self = .scheduled
                case 1: self = .skipped
                case 2: self = .noData
                default: self = .UNRECOGNIZED(rawValue)
                }
            }

            var rawValue: Int {
                switch self {
                case .scheduled: return 0
                case .skipped: return 1
                case .noData: return 2
                case .UNRECOGNIZED(let value): return value
                }
            }
        }

        private var _stopSequence: UInt32?
        private var _arrival: StopTimeEvent?
        private var _departure: StopTimeEvent?
        private var _stopID: String?
        private var _scheduleRelationship: ScheduleRelationship?
        var unknownFields = SwiftProtobuf.UnknownStorage()

        var stopSequence: UInt32 {
            get { _stopSequence ?? 0 }
            set { _stopSequence = newValue }
        }
        var hasStopSequence: Bool { _stopSequence != nil }
        mutating func clearStopSequence() { _stopSequence = nil }

        var arrival: StopTimeEvent {
            get { _arrival ?? StopTimeEvent() }
            set { _arrival = newValue }
        }
        var hasArrival: Bool { _arrival != nil }
        mutating func clearArrival() { _arrival = nil }

        var departure: StopTimeEvent {
            get { _departure ?? StopTimeEvent() }
            set { _departure = newValue }
        }
        var hasDeparture: Bool { _departure != nil }
        mutating func clearDeparture() { _departure = nil }

        var stopID: String {
            get { _stopID ?? "" }
            set { _stopID = newValue }
        }
        var hasStopID: Bool { _stopID != nil }
        mutating func clearStopID() { _stopID = nil }

        var scheduleRelationship: ScheduleRelationship {
            get { _scheduleRelationship ?? .scheduled }
            set { _scheduleRelationship = newValue }
        }
        var hasScheduleRelationship: Bool { _scheduleRelationship != nil }
        mutating func clearScheduleRelationship() { _scheduleRelationship = nil }

        init() {}
    }

    private var _trip: TransitRealtime_TripDescriptor?
    var stopTimeUpdate: [StopTimeUpdate] = []
    private var _vehicle: TransitRealtime_VehicleDescriptor?
    private var _timestamp: UInt64?
    private var _delay: Int32?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var trip: TransitRealtime_TripDescriptor {
        get { _trip ?? TransitRealtime_TripDescriptor() }
        set { _trip = newValue }
    }
    var hasTrip: Bool { _trip != nil }
    mutating func clearTrip() { _trip = nil }

    var vehicle: TransitRealtime_VehicleDescriptor {
        get { _vehicle ?? TransitRealtime_VehicleDescriptor() }
        set { _vehicle = newValue }
    }
    var hasVehicle: Bool { _vehicle != nil }
    mutating func clearVehicle() { _vehicle = nil }

    var timestamp: UInt64 {
        get { _timestamp ?? 0 }
        set { _timestamp = newValue }
    }
    var hasTimestamp: Bool { _timestamp != nil }
    mutating func clearTimestamp() { _timestamp = nil }

    var delay: Int32 {
        get { _delay ?? 0 }
        set { _delay = newValue }
    }
    var hasDelay: Bool { _delay != nil }
    mutating func clearDelay() { _delay = nil }

    init() {}
}

nonisolated struct TransitRealtime_TripDescriptor {
    nonisolated enum ScheduleRelationship: SwiftProtobuf.Enum {
        typealias RawValue = Int

        case scheduled
        case added
        case unscheduled
        case canceled
        case replacement
        case duplicated
        case UNRECOGNIZED(Int)

        init() { self = .scheduled }

        init?(rawValue: Int) {
            switch rawValue {
            case 0: self = .scheduled
            case 1: self = .added
            case 2: self = .unscheduled
            case 3: self = .canceled
            case 5: self = .replacement
            case 6: self = .duplicated
            default: self = .UNRECOGNIZED(rawValue)
            }
        }

        var rawValue: Int {
            switch self {
            case .scheduled: return 0
            case .added: return 1
            case .unscheduled: return 2
            case .canceled: return 3
            case .replacement: return 5
            case .duplicated: return 6
            case .UNRECOGNIZED(let value): return value
            }
        }
    }

    private var _tripID: String?
    private var _startTime: String?
    private var _startDate: String?
    private var _scheduleRelationship: ScheduleRelationship?
    private var _routeID: String?
    private var _directionID: UInt32?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var tripID: String {
        get { _tripID ?? "" }
        set { _tripID = newValue }
    }
    var hasTripID: Bool { _tripID != nil }
    mutating func clearTripID() { _tripID = nil }

    var routeID: String {
        get { _routeID ?? "" }
        set { _routeID = newValue }
    }
    var hasRouteID: Bool { _routeID != nil }
    mutating func clearRouteID() { _routeID = nil }

    var directionID: UInt32 {
        get { _directionID ?? 0 }
        set { _directionID = newValue }
    }
    var hasDirectionID: Bool { _directionID != nil }
    mutating func clearDirectionID() { _directionID = nil }

    var scheduleRelationship: ScheduleRelationship {
        get { _scheduleRelationship ?? .scheduled }
        set { _scheduleRelationship = newValue }
    }
    var hasScheduleRelationship: Bool { _scheduleRelationship != nil }
    mutating func clearScheduleRelationship() { _scheduleRelationship = nil }

    init() {}
}

nonisolated struct TransitRealtime_VehicleDescriptor {
    private var _id: String?
    private var _label: String?
    private var _licensePlate: String?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var id: String {
        get { _id ?? "" }
        set { _id = newValue }
    }
    var hasID: Bool { _id != nil }
    mutating func clearID() { _id = nil }

    var label: String {
        get { _label ?? "" }
        set { _label = newValue }
    }
    var hasLabel: Bool { _label != nil }
    mutating func clearLabel() { _label = nil }

    var licensePlate: String {
        get { _licensePlate ?? "" }
        set { _licensePlate = newValue }
    }
    var hasLicensePlate: Bool { _licensePlate != nil }
    mutating func clearLicensePlate() { _licensePlate = nil }

    init() {}
}

nonisolated struct TransitRealtime_VehiclePosition {
    private var _trip: TransitRealtime_TripDescriptor?
    private var _timestamp: UInt64?
    private var _vehicle: TransitRealtime_VehicleDescriptor?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var trip: TransitRealtime_TripDescriptor {
        get { _trip ?? TransitRealtime_TripDescriptor() }
        set { _trip = newValue }
    }
    var hasTrip: Bool { _trip != nil }
    mutating func clearTrip() { _trip = nil }

    var timestamp: UInt64 {
        get { _timestamp ?? 0 }
        set { _timestamp = newValue }
    }
    var hasTimestamp: Bool { _timestamp != nil }
    mutating func clearTimestamp() { _timestamp = nil }

    var vehicle: TransitRealtime_VehicleDescriptor {
        get { _vehicle ?? TransitRealtime_VehicleDescriptor() }
        set { _vehicle = newValue }
    }
    var hasVehicle: Bool { _vehicle != nil }
    mutating func clearVehicle() { _vehicle = nil }

    init() {}
}

nonisolated struct TransitRealtime_Alert {
    var activePeriod: [TransitRealtime_TimeRange] = []
    var informedEntity: [TransitRealtime_EntitySelector] = []
    private var _cause: Cause?
    private var _effect: Effect?
    private var _url: TransitRealtime_TranslatedString?
    private var _headerText: TransitRealtime_TranslatedString?
    private var _descriptionText: TransitRealtime_TranslatedString?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    nonisolated enum Cause: SwiftProtobuf.Enum {
        typealias RawValue = Int

        case unknownCause
        case otherCause
        case technicalProblem
        case strike
        case demonstration
        case accident
        case holiday
        case weather
        case maintenance
        case construction
        case policeActivity
        case medicalEmergency
        case UNRECOGNIZED(Int)

        init() { self = .unknownCause }

        init?(rawValue: Int) {
            switch rawValue {
            case 1: self = .unknownCause
            case 2: self = .otherCause
            case 3: self = .technicalProblem
            case 4: self = .strike
            case 5: self = .demonstration
            case 6: self = .accident
            case 7: self = .holiday
            case 8: self = .weather
            case 9: self = .maintenance
            case 10: self = .construction
            case 11: self = .policeActivity
            case 12: self = .medicalEmergency
            default: self = .UNRECOGNIZED(rawValue)
            }
        }

        var rawValue: Int {
            switch self {
            case .unknownCause: return 1
            case .otherCause: return 2
            case .technicalProblem: return 3
            case .strike: return 4
            case .demonstration: return 5
            case .accident: return 6
            case .holiday: return 7
            case .weather: return 8
            case .maintenance: return 9
            case .construction: return 10
            case .policeActivity: return 11
            case .medicalEmergency: return 12
            case .UNRECOGNIZED(let value): return value
            }
        }
    }

    nonisolated enum Effect: SwiftProtobuf.Enum {
        typealias RawValue = Int

        case noService
        case reducedService
        case significantDelays
        case detour
        case additionalService
        case modifiedService
        case otherEffect
        case unknownEffect
        case stopMoved
        case noEffect
        case accessibilityIssue
        case UNRECOGNIZED(Int)

        init() { self = .unknownEffect }

        init?(rawValue: Int) {
            switch rawValue {
            case 1: self = .noService
            case 2: self = .reducedService
            case 3: self = .significantDelays
            case 4: self = .detour
            case 5: self = .additionalService
            case 6: self = .modifiedService
            case 7: self = .otherEffect
            case 8: self = .unknownEffect
            case 9: self = .stopMoved
            case 10: self = .noEffect
            case 11: self = .accessibilityIssue
            default: self = .UNRECOGNIZED(rawValue)
            }
        }

        var rawValue: Int {
            switch self {
            case .noService: return 1
            case .reducedService: return 2
            case .significantDelays: return 3
            case .detour: return 4
            case .additionalService: return 5
            case .modifiedService: return 6
            case .otherEffect: return 7
            case .unknownEffect: return 8
            case .stopMoved: return 9
            case .noEffect: return 10
            case .accessibilityIssue: return 11
            case .UNRECOGNIZED(let value): return value
            }
        }
    }

    var cause: Cause {
        get { _cause ?? .unknownCause }
        set { _cause = newValue }
    }

    var effect: Effect {
        get { _effect ?? .unknownEffect }
        set { _effect = newValue }
    }

    var url: TransitRealtime_TranslatedString {
        get { _url ?? TransitRealtime_TranslatedString() }
        set { _url = newValue }
    }
    var hasURL: Bool { _url != nil }

    var headerText: TransitRealtime_TranslatedString {
        get { _headerText ?? TransitRealtime_TranslatedString() }
        set { _headerText = newValue }
    }
    var hasHeaderText: Bool { _headerText != nil }

    var descriptionText: TransitRealtime_TranslatedString {
        get { _descriptionText ?? TransitRealtime_TranslatedString() }
        set { _descriptionText = newValue }
    }
    var hasDescriptionText: Bool { _descriptionText != nil }

    init() {}
}

nonisolated struct TransitRealtime_EntitySelector {
    private var _agencyID: String?
    private var _routeID: String?
    private var _routeType: Int32?
    private var _trip: TransitRealtime_TripDescriptor?
    private var _stopID: String?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var agencyID: String {
        get { _agencyID ?? "" }
        set { _agencyID = newValue }
    }
    var hasAgencyID: Bool { _agencyID != nil }

    var routeID: String {
        get { _routeID ?? "" }
        set { _routeID = newValue }
    }
    var hasRouteID: Bool { _routeID != nil }

    var routeType: Int32 {
        get { _routeType ?? 0 }
        set { _routeType = newValue }
    }
    var hasRouteType: Bool { _routeType != nil }

    var trip: TransitRealtime_TripDescriptor {
        get { _trip ?? TransitRealtime_TripDescriptor() }
        set { _trip = newValue }
    }
    var hasTrip: Bool { _trip != nil }

    var stopID: String {
        get { _stopID ?? "" }
        set { _stopID = newValue }
    }
    var hasStopID: Bool { _stopID != nil }

    init() {}
}

nonisolated struct TransitRealtime_TimeRange {
    private var _start: UInt64?
    private var _end: UInt64?
    var unknownFields = SwiftProtobuf.UnknownStorage()

    var start: UInt64 {
        get { _start ?? 0 }
        set { _start = newValue }
    }
    var hasStart: Bool { _start != nil }

    var end: UInt64 {
        get { _end ?? 0 }
        set { _end = newValue }
    }
    var hasEnd: Bool { _end != nil }

    init() {}
}

nonisolated struct TransitRealtime_TranslatedString {
    nonisolated struct Translation {
        var text = ""
        var language = ""
        var unknownFields = SwiftProtobuf.UnknownStorage()

        init() {}
    }

    var translation: [Translation] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
}

// MARK: - Message conformance

nonisolated extension TransitRealtime_FeedMessage: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.FeedMessage"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { hasHeader && header.isInitialized && entity.allSatisfy(\.isInitialized) }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &_header)
            case 2: try decoder.decodeRepeatedMessageField(value: &entity)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _header { try visitor.visitSingularMessageField(value: value, fieldNumber: 1) }
        try visitor.visitRepeatedMessageField(value: entity, fieldNumber: 2)
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_FeedMessage, rhs: TransitRealtime_FeedMessage) -> Bool {
        lhs._header == rhs._header && lhs.entity == rhs.entity && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_FeedHeader: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.FeedHeader"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { hasGtfsRealtimeVersion }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &_gtfsRealtimeVersion)
            case 2: try decoder.decodeSingularEnumField(value: &_incrementality)
            case 3: try decoder.decodeSingularUInt64Field(value: &_timestamp)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _gtfsRealtimeVersion { try visitor.visitSingularStringField(value: value, fieldNumber: 1) }
        if let value = _incrementality { try visitor.visitSingularEnumField(value: value, fieldNumber: 2) }
        if let value = _timestamp { try visitor.visitSingularUInt64Field(value: value, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_FeedHeader, rhs: TransitRealtime_FeedHeader) -> Bool {
        lhs._gtfsRealtimeVersion == rhs._gtfsRealtimeVersion
            && lhs._incrementality == rhs._incrementality
            && lhs._timestamp == rhs._timestamp
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_FeedEntity: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.FeedEntity"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { hasID }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &_id)
            case 2: try decoder.decodeSingularBoolField(value: &_isDeleted)
            case 3: try decoder.decodeSingularMessageField(value: &_tripUpdate)
            case 4: try decoder.decodeSingularMessageField(value: &_vehicle)
            case 5: try decoder.decodeSingularMessageField(value: &_alert)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _id { try visitor.visitSingularStringField(value: value, fieldNumber: 1) }
        if let value = _isDeleted { try visitor.visitSingularBoolField(value: value, fieldNumber: 2) }
        if let value = _tripUpdate { try visitor.visitSingularMessageField(value: value, fieldNumber: 3) }
        if let value = _vehicle { try visitor.visitSingularMessageField(value: value, fieldNumber: 4) }
        if let value = _alert { try visitor.visitSingularMessageField(value: value, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_FeedEntity, rhs: TransitRealtime_FeedEntity) -> Bool {
        lhs._id == rhs._id
            && lhs._isDeleted == rhs._isDeleted
            && lhs._tripUpdate == rhs._tripUpdate
            && lhs._vehicle == rhs._vehicle
            && lhs._alert == rhs._alert
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_TripUpdate: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.TripUpdate"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { hasTrip && stopTimeUpdate.allSatisfy(\.isInitialized) }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &_trip)
            case 2: try decoder.decodeRepeatedMessageField(value: &stopTimeUpdate)
            case 3: try decoder.decodeSingularMessageField(value: &_vehicle)
            case 4: try decoder.decodeSingularUInt64Field(value: &_timestamp)
            case 5: try decoder.decodeSingularInt32Field(value: &_delay)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _trip { try visitor.visitSingularMessageField(value: value, fieldNumber: 1) }
        try visitor.visitRepeatedMessageField(value: stopTimeUpdate, fieldNumber: 2)
        if let value = _vehicle { try visitor.visitSingularMessageField(value: value, fieldNumber: 3) }
        if let value = _timestamp { try visitor.visitSingularUInt64Field(value: value, fieldNumber: 4) }
        if let value = _delay { try visitor.visitSingularInt32Field(value: value, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_TripUpdate, rhs: TransitRealtime_TripUpdate) -> Bool {
        lhs._trip == rhs._trip
            && lhs.stopTimeUpdate == rhs.stopTimeUpdate
            && lhs._vehicle == rhs._vehicle
            && lhs._timestamp == rhs._timestamp
            && lhs._delay == rhs._delay
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_TripUpdate.StopTimeEvent: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.TripUpdate.StopTimeEvent"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { true }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt32Field(value: &_delay)
            case 2: try decoder.decodeSingularInt64Field(value: &_time)
            case 3: try decoder.decodeSingularInt32Field(value: &_uncertainty)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _delay { try visitor.visitSingularInt32Field(value: value, fieldNumber: 1) }
        if let value = _time { try visitor.visitSingularInt64Field(value: value, fieldNumber: 2) }
        if let value = _uncertainty { try visitor.visitSingularInt32Field(value: value, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_TripUpdate.StopTimeEvent, rhs: TransitRealtime_TripUpdate.StopTimeEvent) -> Bool {
        lhs._delay == rhs._delay
            && lhs._time == rhs._time
            && lhs._uncertainty == rhs._uncertainty
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_TripUpdate.StopTimeUpdate: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.TripUpdate.StopTimeUpdate"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { true }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularUInt32Field(value: &_stopSequence)
            case 2: try decoder.decodeSingularMessageField(value: &_arrival)
            case 3: try decoder.decodeSingularMessageField(value: &_departure)
            case 4: try decoder.decodeSingularStringField(value: &_stopID)
            case 5: try decoder.decodeSingularEnumField(value: &_scheduleRelationship)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _stopSequence { try visitor.visitSingularUInt32Field(value: value, fieldNumber: 1) }
        if let value = _arrival { try visitor.visitSingularMessageField(value: value, fieldNumber: 2) }
        if let value = _departure { try visitor.visitSingularMessageField(value: value, fieldNumber: 3) }
        if let value = _stopID { try visitor.visitSingularStringField(value: value, fieldNumber: 4) }
        if let value = _scheduleRelationship { try visitor.visitSingularEnumField(value: value, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_TripUpdate.StopTimeUpdate, rhs: TransitRealtime_TripUpdate.StopTimeUpdate) -> Bool {
        lhs._stopSequence == rhs._stopSequence
            && lhs._arrival == rhs._arrival
            && lhs._departure == rhs._departure
            && lhs._stopID == rhs._stopID
            && lhs._scheduleRelationship == rhs._scheduleRelationship
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_TripDescriptor: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.TripDescriptor"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { true }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &_tripID)
            case 2: try decoder.decodeSingularStringField(value: &_startTime)
            case 3: try decoder.decodeSingularStringField(value: &_startDate)
            case 4: try decoder.decodeSingularEnumField(value: &_scheduleRelationship)
            case 5: try decoder.decodeSingularStringField(value: &_routeID)
            case 6: try decoder.decodeSingularUInt32Field(value: &_directionID)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _tripID { try visitor.visitSingularStringField(value: value, fieldNumber: 1) }
        if let value = _startTime { try visitor.visitSingularStringField(value: value, fieldNumber: 2) }
        if let value = _startDate { try visitor.visitSingularStringField(value: value, fieldNumber: 3) }
        if let value = _scheduleRelationship { try visitor.visitSingularEnumField(value: value, fieldNumber: 4) }
        if let value = _routeID { try visitor.visitSingularStringField(value: value, fieldNumber: 5) }
        if let value = _directionID { try visitor.visitSingularUInt32Field(value: value, fieldNumber: 6) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_TripDescriptor, rhs: TransitRealtime_TripDescriptor) -> Bool {
        lhs._tripID == rhs._tripID
            && lhs._startTime == rhs._startTime
            && lhs._startDate == rhs._startDate
            && lhs._scheduleRelationship == rhs._scheduleRelationship
            && lhs._routeID == rhs._routeID
            && lhs._directionID == rhs._directionID
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_VehicleDescriptor: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.VehicleDescriptor"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { true }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &_id)
            case 2: try decoder.decodeSingularStringField(value: &_label)
            case 3: try decoder.decodeSingularStringField(value: &_licensePlate)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _id { try visitor.visitSingularStringField(value: value, fieldNumber: 1) }
        if let value = _label { try visitor.visitSingularStringField(value: value, fieldNumber: 2) }
        if let value = _licensePlate { try visitor.visitSingularStringField(value: value, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_VehicleDescriptor, rhs: TransitRealtime_VehicleDescriptor) -> Bool {
        lhs._id == rhs._id
            && lhs._label == rhs._label
            && lhs._licensePlate == rhs._licensePlate
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_VehiclePosition: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.VehiclePosition"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { true }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &_trip)
            case 5: try decoder.decodeSingularUInt64Field(value: &_timestamp)
            case 8: try decoder.decodeSingularMessageField(value: &_vehicle)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _trip { try visitor.visitSingularMessageField(value: value, fieldNumber: 1) }
        if let value = _timestamp { try visitor.visitSingularUInt64Field(value: value, fieldNumber: 5) }
        if let value = _vehicle { try visitor.visitSingularMessageField(value: value, fieldNumber: 8) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_VehiclePosition, rhs: TransitRealtime_VehiclePosition) -> Bool {
        lhs._trip == rhs._trip
            && lhs._timestamp == rhs._timestamp
            && lhs._vehicle == rhs._vehicle
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_Alert: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.Alert"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { true }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &activePeriod)
            case 5: try decoder.decodeRepeatedMessageField(value: &informedEntity)
            case 6: try decoder.decodeSingularEnumField(value: &_cause)
            case 7: try decoder.decodeSingularEnumField(value: &_effect)
            case 8: try decoder.decodeSingularMessageField(value: &_url)
            case 10: try decoder.decodeSingularMessageField(value: &_headerText)
            case 11: try decoder.decodeSingularMessageField(value: &_descriptionText)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try visitor.visitRepeatedMessageField(value: activePeriod, fieldNumber: 1)
        try visitor.visitRepeatedMessageField(value: informedEntity, fieldNumber: 5)
        if let value = _cause { try visitor.visitSingularEnumField(value: value, fieldNumber: 6) }
        if let value = _effect { try visitor.visitSingularEnumField(value: value, fieldNumber: 7) }
        if let value = _url { try visitor.visitSingularMessageField(value: value, fieldNumber: 8) }
        if let value = _headerText { try visitor.visitSingularMessageField(value: value, fieldNumber: 10) }
        if let value = _descriptionText { try visitor.visitSingularMessageField(value: value, fieldNumber: 11) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_Alert, rhs: TransitRealtime_Alert) -> Bool {
        lhs.activePeriod == rhs.activePeriod
            && lhs.informedEntity == rhs.informedEntity
            && lhs._cause == rhs._cause
            && lhs._effect == rhs._effect
            && lhs._url == rhs._url
            && lhs._headerText == rhs._headerText
            && lhs._descriptionText == rhs._descriptionText
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_EntitySelector: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.EntitySelector"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { true }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &_agencyID)
            case 2: try decoder.decodeSingularStringField(value: &_routeID)
            case 3: try decoder.decodeSingularInt32Field(value: &_routeType)
            case 4: try decoder.decodeSingularMessageField(value: &_trip)
            case 5: try decoder.decodeSingularStringField(value: &_stopID)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _agencyID { try visitor.visitSingularStringField(value: value, fieldNumber: 1) }
        if let value = _routeID { try visitor.visitSingularStringField(value: value, fieldNumber: 2) }
        if let value = _routeType { try visitor.visitSingularInt32Field(value: value, fieldNumber: 3) }
        if let value = _trip { try visitor.visitSingularMessageField(value: value, fieldNumber: 4) }
        if let value = _stopID { try visitor.visitSingularStringField(value: value, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_EntitySelector, rhs: TransitRealtime_EntitySelector) -> Bool {
        lhs._agencyID == rhs._agencyID
            && lhs._routeID == rhs._routeID
            && lhs._routeType == rhs._routeType
            && lhs._trip == rhs._trip
            && lhs._stopID == rhs._stopID
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_TimeRange: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.TimeRange"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { true }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularUInt64Field(value: &_start)
            case 2: try decoder.decodeSingularUInt64Field(value: &_end)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let value = _start { try visitor.visitSingularUInt64Field(value: value, fieldNumber: 1) }
        if let value = _end { try visitor.visitSingularUInt64Field(value: value, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_TimeRange, rhs: TransitRealtime_TimeRange) -> Bool {
        lhs._start == rhs._start
            && lhs._end == rhs._end
            && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_TranslatedString: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.TranslatedString"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { translation.allSatisfy(\.isInitialized) }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &translation)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try visitor.visitRepeatedMessageField(value: translation, fieldNumber: 1)
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_TranslatedString, rhs: TransitRealtime_TranslatedString) -> Bool {
        lhs.translation == rhs.translation && lhs.unknownFields == rhs.unknownFields
    }
}

nonisolated extension TransitRealtime_TranslatedString.Translation: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "transit_realtime.TranslatedString.Translation"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    var isInitialized: Bool { !text.isEmpty }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &text)
            case 2: try decoder.decodeSingularStringField(value: &language)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !text.isEmpty { try visitor.visitSingularStringField(value: text, fieldNumber: 1) }
        if !language.isEmpty { try visitor.visitSingularStringField(value: language, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TransitRealtime_TranslatedString.Translation, rhs: TransitRealtime_TranslatedString.Translation) -> Bool {
        lhs.text == rhs.text
            && lhs.language == rhs.language
            && lhs.unknownFields == rhs.unknownFields
    }
}
