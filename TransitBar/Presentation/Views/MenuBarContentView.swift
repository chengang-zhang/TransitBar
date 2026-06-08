import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: TransitBarViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var departureTopHintOpacity: CGFloat = 0
    @State private var departureBottomHintOpacity: CGFloat = 1
    private let menuWidth: CGFloat = 420
    private let contentHorizontalPadding: CGFloat = 16
    private let departureRowSpacing: CGFloat = 10
    private let departureTimeWidth: CGFloat = 64

    private var contentWidth: CGFloat {
        menuWidth - (contentHorizontalPadding * 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.primary)
            } else if viewModel.favorites.isEmpty {
                Text("Add a favorite stop to get started.")
                    .foregroundStyle(.primary)
            } else if viewModel.departureSections.isEmpty {
                Text(viewModel.isLoadingDepartures ? "Loading departures..." : "No scheduled departures found.")
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(width: contentWidth, alignment: .leading)
            } else if viewModel.departureSections.count > 3 {
                scrollableDepartureSections
            } else {
                departureSections(width: contentWidth)
            }

            Divider()

            Button("Open TransitBar") {
                openWindow(id: "favorites")
                surfaceTransitBarWindow()
            }
            .buttonStyle(.plain)
            .frame(width: contentWidth, alignment: .leading)

            Button("Refresh") {
                viewModel.refreshDepartures()
            }
            .buttonStyle(.plain)
            .frame(width: contentWidth, alignment: .leading)

            Divider()

            Button("Quit TransitBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .frame(width: contentWidth, alignment: .leading)
        }
        .frame(width: contentWidth)
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.vertical, 10)
        .onAppear {
            viewModel.refreshDepartures()
        }
    }

    private var scrollableDepartureSections: some View {
        ZStack {
            DepartureScrollView(
                width: contentWidth,
                contentRevision: departureContentRevision,
                topHintOpacity: $departureTopHintOpacity,
                bottomHintOpacity: $departureBottomHintOpacity
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    departureSections(width: contentWidth)
                }
            }

            ScrollHintScrim(edge: .top)
                .opacity(departureTopHintOpacity)
                .padding(.horizontal, -contentHorizontalPadding)
                .padding(.top, -10)

            ScrollHintScrim(edge: .bottom)
                .opacity(departureBottomHintOpacity)
                .padding(.horizontal, -contentHorizontalPadding)
                .padding(.bottom, -12)
        }
        .frame(height: 360)
        .onAppear {
            departureBottomHintOpacity = 1
        }
    }

    private var departureContentRevision: String {
        viewModel.departureSections
            .map { section in
                let departureIds = section.departures
                    .prefix(viewModel.maxDeparturesPerStop)
                    .map { "\($0.id):\($0.departureTime.timeIntervalSinceReferenceDate):\($0.predictionSource.rawValue)" }
                    .joined(separator: ",")
                return "\(section.id):\(section.alerts.count):\(departureIds)"
            }
            .joined(separator: "|")
    }

    private func departureSections(width: CGFloat) -> some View {
        ForEach(viewModel.departureSections) { section in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(section.favorite.stopName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if viewModel.isPrimary(section.favorite) {
                        Text("Primary")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.72))
                            .fixedSize()
                    }
                    if !section.alerts.isEmpty {
                        alertMenu(for: section.alerts, title: viewModel.alertTitle(for: section))
                    }
                }
                .frame(width: width, alignment: .leading)

                if section.departures.isEmpty {
                    Text("No scheduled departures found.")
                        .foregroundStyle(.primary.opacity(0.72))
                } else {
                    ForEach(section.departures.prefix(viewModel.maxDeparturesPerStop)) { departure in
                        let badgeWidth = RouteBadgeImageFactory.size(for: departure).width

                        HStack(alignment: .center, spacing: departureRowSpacing) {
                            RouteBadgeView(departure: departure)
                                .frame(width: badgeWidth, alignment: .leading)
                            Text(departure.destination)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 6) {
                                DepartureCountdownText(
                                    departureTime: departure.departureTime,
                                    showsSecondsForNearDepartures: viewModel.showsSecondsForNearDepartures
                                )
                                .frame(width: departureTimeWidth, alignment: .trailing)
                                PredictionSourceIndicator(predictionSource: departure.predictionSource)
                            }
                        }
                        .frame(width: width, alignment: .leading)
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(width: width, alignment: .leading)

            if section.id != viewModel.departureSections.last?.id {
                Divider()
            }
        }
    }

    private func alertMenu(for alerts: [RealtimeAlert], title: String) -> some View {
        Menu {
            ForEach(alerts, id: \.id) { alert in
                Text(alert.headerText ?? "Service alert")
                if let descriptionText = alert.descriptionText, !descriptionText.isEmpty {
                    Text(descriptionText)
                }
            }
        } label: {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.yellow)
        }
        .menuStyle(.borderlessButton)
        .help(title)
    }

    private func surfaceTransitBarWindow() {
        DispatchQueue.main.async {
            NSApplication.shared.activate()
            NSApplication.shared.windows
                .first { $0.title == "TransitBar" }?
                .makeKeyAndOrderFront(nil)
        }
    }
}

private struct DepartureCountdownText: View {
    let departureTime: Date
    let showsSecondsForNearDepartures: Bool

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            Text(Self.text(for: departureTime, relativeTo: context.date, showsSecondsForNearDepartures: showsSecondsForNearDepartures))
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }

    private static func text(
        for departureTime: Date,
        relativeTo date: Date,
        showsSecondsForNearDepartures: Bool
    ) -> String {
        let seconds = max(0, Int(departureTime.timeIntervalSince(date)))
        if seconds < 5 * 60 {
            guard showsSecondsForNearDepartures else {
                return "\(max(1, (seconds + 59) / 60))m"
            }

            let minutes = seconds / 60
            let remainingSeconds = seconds % 60

            if minutes == 0 {
                return "\(remainingSeconds)s"
            }

            return "\(minutes)m \(remainingSeconds)s"
        }

        if seconds > 60 * 60 {
            if Calendar.current.isDate(departureTime, inSameDayAs: date) {
                return sameDayDepartureFormatter.string(from: departureTime)
            }

            return futureDayDepartureFormatter.string(from: departureTime)
        }

        return "\(seconds / 60)m"
    }

    private static let sameDayDepartureFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let futureDayDepartureFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE h:mm a")
        return formatter
    }()
}

private struct ScrollHintScrim: View {
    enum Edge {
        case top
        case bottom
    }

    let edge: Edge

    var body: some View {
        VStack {
            if edge == .bottom {
                Spacer()
            }

            ZStack {
                scrim
                Image(systemName: edge == .top ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.9))
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                    .padding(edge == .top ? .top : .bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64, alignment: edge == .top ? .top : .bottom)

            if edge == .top {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var scrim: some View {
        LinearGradient(
            colors: edge == .top
                ? [Color.black.opacity(0.5), Color.black.opacity(0)]
                : [Color.black.opacity(0), Color.black.opacity(0.5)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DepartureScrollView<Content: View>: NSViewRepresentable {
    let width: CGFloat
    let contentRevision: String
    let content: Content
    @Binding var topHintOpacity: CGFloat
    @Binding var bottomHintOpacity: CGFloat

    init(
        width: CGFloat,
        contentRevision: String,
        topHintOpacity: Binding<CGFloat>,
        bottomHintOpacity: Binding<CGFloat>,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.contentRevision = contentRevision
        self._topHintOpacity = topHintOpacity
        self._bottomHintOpacity = bottomHintOpacity
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(topHintOpacity: $topHintOpacity, bottomHintOpacity: $bottomHintOpacity)
    }

    func makeNSView(context: Context) -> DepartureScrollContainerView<Content> {
        let view = DepartureScrollContainerView(rootView: content, width: width, contentRevision: contentRevision)
        view.onStateChange = context.coordinator.update(topHintOpacity:bottomHintOpacity:)
        return view
    }

    func updateNSView(_ nsView: DepartureScrollContainerView<Content>, context: Context) {
        context.coordinator.topHintOpacity = $topHintOpacity
        context.coordinator.bottomHintOpacity = $bottomHintOpacity
        nsView.onStateChange = context.coordinator.update(topHintOpacity:bottomHintOpacity:)
        nsView.update(rootView: content, width: width, contentRevision: contentRevision)
    }

    final class Coordinator {
        var topHintOpacity: Binding<CGFloat>
        var bottomHintOpacity: Binding<CGFloat>

        init(topHintOpacity: Binding<CGFloat>, bottomHintOpacity: Binding<CGFloat>) {
            self.topHintOpacity = topHintOpacity
            self.bottomHintOpacity = bottomHintOpacity
        }

        func update(topHintOpacity: CGFloat, bottomHintOpacity: CGFloat) {
            let opacityEpsilon: CGFloat = 0.01
            guard abs(self.topHintOpacity.wrappedValue - topHintOpacity) > opacityEpsilon ||
                    abs(self.bottomHintOpacity.wrappedValue - bottomHintOpacity) > opacityEpsilon
            else {
                return
            }

            DispatchQueue.main.async {
                self.topHintOpacity.wrappedValue = topHintOpacity
                self.bottomHintOpacity.wrappedValue = bottomHintOpacity
            }
        }
    }
}

private final class DepartureScrollContainerView<Content: View>: NSView {
    var onStateChange: ((CGFloat, CGFloat) -> Void)?
    private let scrollView = NSScrollView()
    private let hostingView: NSHostingView<Content>
    private var contentWidth: CGFloat
    private var contentRevision: String
    nonisolated(unsafe) private var boundsObserver: NSObjectProtocol?
    nonisolated(unsafe) private var documentFrameObserver: NSObjectProtocol?

    init(rootView: Content, width: CGFloat, contentRevision: String) {
        self.hostingView = NSHostingView(rootView: rootView)
        self.contentWidth = width
        self.contentRevision = contentRevision
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
        if let documentFrameObserver {
            NotificationCenter.default.removeObserver(documentFrameObserver)
        }
    }

    override func layout() {
        super.layout()
        layoutScrollContent(preserving: scrollView.contentView.bounds.origin)
    }

    func update(rootView: Content, width: CGFloat, contentRevision: String) {
        let previousOrigin = scrollView.contentView.bounds.origin
        let needsContentUpdate = self.contentRevision != contentRevision
        let needsWidthUpdate = abs(contentWidth - width) > 0.5

        guard needsContentUpdate || needsWidthUpdate else {
            updateScrollState()
            return
        }

        if needsContentUpdate {
            hostingView.rootView = rootView
            self.contentRevision = contentRevision
        }
        contentWidth = width
        needsLayout = true
        layoutSubtreeIfNeeded()
        layoutScrollContent(preserving: previousOrigin)
        scheduleDeferredMeasurements()
    }

    private func configure() {
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScroller?.isHidden = true
        scrollView.horizontalScroller?.isHidden = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        hostingView.postsFrameChangedNotifications = true
        scrollView.documentView = hostingView
        addSubview(scrollView)

        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateScrollState()
            }
        }
        documentFrameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: hostingView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateScrollState()
            }
        }

        scheduleDeferredMeasurements()
    }

    private func layoutScrollContent(preserving previousOrigin: CGPoint? = nil) {
        scrollView.frame = bounds
        let viewportHeight = scrollView.contentView.bounds.height
        let fittingSize = hostingView.fittingSize
        let contentHeight = max(fittingSize.height, viewportHeight)
        let newFrame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)

        if hostingView.frame != newFrame {
            hostingView.frame = newFrame
        }

        if let previousOrigin {
            let maxY = max(contentHeight - viewportHeight, 0)
            let clampedOrigin = CGPoint(
                x: 0,
                y: min(max(previousOrigin.y, 0), maxY)
            )
            scrollView.contentView.scroll(to: clampedOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        updateScrollState()
    }

    private func updateScrollState() {
        let visibleRect = scrollView.documentVisibleRect
        let contentHeight = hostingView.bounds.height
        let viewportHeight = visibleRect.height
        guard contentHeight > viewportHeight else {
            onStateChange?(0, 0)
            return
        }

        let distanceFromTop = visibleRect.minY
        let distanceFromBottom = contentHeight - visibleRect.maxY

        let topOpacity = Self.hintOpacity(for: distanceFromTop, start: 8, full: 56)
        let bottomOpacity = Self.hintOpacity(for: distanceFromBottom, start: 0, full: 64)
        onStateChange?(topOpacity, bottomOpacity)
    }

    private static func hintOpacity(for distance: CGFloat, start: CGFloat, full: CGFloat) -> CGFloat {
        guard distance > start else { return 0 }
        let range = max(full - start, 1)
        return min(max((distance - start) / range, 0), 1)
    }

    private func scheduleDeferredMeasurements() {
        [0.05, 0.2, 0.5].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.updateScrollState()
            }
        }
    }
}

private struct PredictionSourceIndicator: View {
    let predictionSource: ArrivalPredictionSource

    @ViewBuilder
    var body: some View {
        switch predictionSource {
        case .realtime:
            PulsingLiveDot()
                .frame(width: 12, height: 12)
                .accessibilityLabel(accessibilityLabel)
        case .canceled, .skipped:
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .frame(width: 12, height: 12)
                .accessibilityLabel(accessibilityLabel)
        case .scheduled:
            EmptyView()
        }
    }

    private var accessibilityLabel: String {
        switch predictionSource {
        case .realtime:
            return "Live arrival"
        case .canceled:
            return "Canceled arrival"
        case .skipped:
            return "Skipped arrival"
        case .scheduled:
            return "Scheduled arrival"
        }
    }
}

private struct PulsingLiveDot: NSViewRepresentable {
    func makeNSView(context: Context) -> LiveDotView {
        LiveDotView()
    }

    func updateNSView(_ nsView: LiveDotView, context: Context) {
        nsView.startPulsing()
    }
}

private final class LiveDotView: NSView {
    private let dotLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 12, height: 12)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.frame = CGRect(
            x: (bounds.width - 6) / 2,
            y: (bounds.height - 6) / 2,
            width: 6,
            height: 6
        )
        dotLayer.cornerRadius = 3
        CATransaction.commit()
    }

    func startPulsing() {
        guard dotLayer.animation(forKey: "livePulse") == nil else { return }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.32
        animation.duration = 0.9
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dotLayer.add(animation, forKey: "livePulse")
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        dotLayer.backgroundColor = NSColor.systemGreen.cgColor
        layer?.addSublayer(dotLayer)
        startPulsing()
    }
}
