//
//  CircularRangeSlider.swift
//
//  Created by Diego Rivera on 16/5/25.
//

import SwiftUI

public struct CircularRangeSlider: View {
    @Binding var range: ClosedRange<Double>
    var bounds: ClosedRange<Double>
    var circleDiameter: CGFloat
    var arcTrimmingDegrees: CGFloat
    var trackWidth: CGFloat
    var handleWidth: CGFloat
    var color: Color
    var step: Double
    
    @usableFromInline static var defaultCircleDiameter: CGFloat { 220 }
    @usableFromInline static var defaultArcTrimmingDegrees: CGFloat { 75 }
    @usableFromInline static var defaultTrackWidth: CGFloat { 45 }
    @usableFromInline static var defaultHandleWidth: CGFloat { 36 }

    public init(
        range: Binding<ClosedRange<Double>>,
        bounds: ClosedRange<Double>,
        circleDiameter: CGFloat = CircularRangeSlider.defaultCircleDiameter,
        arcTrimmingDegrees: CGFloat = CircularRangeSlider.defaultArcTrimmingDegrees,
        trackWidth: CGFloat = CircularRangeSlider.defaultTrackWidth,
        handleWidth: CGFloat = CircularRangeSlider.defaultHandleWidth,
        color: Color? = nil,
        step: Double? = nil
    ) {
        self._range = range
        self.bounds = bounds
        self.circleDiameter = circleDiameter
        self.arcTrimmingDegrees = arcTrimmingDegrees
        self.trackWidth = trackWidth
        self.handleWidth = handleWidth
        self.color = color ?? .accentColor
        self.step = step ?? CircularRangeSlider.defaultBoundsStep(for: bounds)
    }
    
    private var handleSizeDegrees: CGFloat {
        360 * (handleWidth / (CGFloat.pi * circleDiameter))
    }
    
    private var rangeDegrees: ClosedRange<Double> {
        let lower = range.lowerBound
        let upper = range.upperBound
        return angleFromValue(lower).degrees...angleFromValue(upper).degrees
    }
    
    private var boundsDegrees: ClosedRange<Double> {
        let start = arcTrimmingDegrees / 2
        let end = 360 - (arcTrimmingDegrees / 2)
        return start...end
    }

    @State private var startDragOffset: Angle = .zero
    @State private var endDragOffset: Angle = .zero
    @State private var lastHapticAngle: Angle?
    @State private var draggingHandle: Handle?
    @GestureState private var activeDragAngle: Angle?
    
    static let sliderAnimationSteps: Int = 20
    static let sliderAnimationDuration: Double = 0.3
    @State private var showSlider: Bool = true

    public var body: some View {
        ZStack {
            trimmedCircleTrack()
            if showSlider {
                arcView()
                    .gesture(dragGesture(for: .arc))
                handleView(at: range.lowerBound)
                    .gesture(dragGesture(for: .start))
                handleView(at: range.upperBound)
                    .gesture(dragGesture(for: .end))
            }
        }
        .onChange(of: bounds) { oldValue, _ in
            clampRangeIfNeeded(fromPriorBounds: oldValue)
        }
        .frame(width: circleDiameter, height: circleDiameter)
    }

    @ViewBuilder
    private func trimmedCircleTrack() -> some View {
        Circle()
            .trim(from: CGFloat(boundsDegrees.lowerBound) / 360,
                  to: CGFloat(boundsDegrees.upperBound) / 360)
            .stroke(Color(uiColor: .lightGray).opacity(0.15),
                    style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
            .rotationEffect(.degrees(90))
    }

    @ViewBuilder
    private func arcView() -> some View {
        CircleArc(
            startAngle: angleFromValue(range.lowerBound),
            endAngle: angleFromValue(range.upperBound)
        )
        .stroke(color, lineWidth: min(handleWidth, trackWidth))
    }

    @ViewBuilder
    private func handleView(at value: Double) -> some View {
        let angle: Angle = angleFromValue(value)
        let handleRadius = handleWidth / 2
        let circleRadius: CGFloat = circleDiameter / 2
        let x = circleRadius * (1 + cos(CGFloat(angle.radians - (3 * .pi / 2))))
        let y = circleRadius * (1 + sin(CGFloat(angle.radians - (3 * .pi / 2))))
        ZStack {
            Circle()
                .fill(color)
                .frame(width: handleRadius * 2, height: handleRadius * 2)
                .position(x: x, y: y)
            Image(systemName: "circle.hexagongrid.fill")
                .resizable()
                .scaledToFit()
                .frame(width: handleRadius * 1.25, height: handleRadius * 1.25)
                .foregroundStyle(Color(uiColor: .systemBackground).opacity(0.25))
                .rotationEffect(angle)
                .position(x: x, y: y)
        }
    }
}

private extension CircularRangeSlider {
    struct CircleArc: Shape {
        var startAngle: Angle
        var endAngle: Angle

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let radius = min(rect.width, rect.height) / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle - .degrees(270),
                endAngle: endAngle - .degrees(270),
                clockwise: false
            )
            return path
        }
    }
    
    enum Handle {
        case start, end, arc
    }

    func angleFromDrag(location: CGPoint) -> Angle {
        let radius = circleDiameter / 2
        let center = CGPoint(x: radius, y: radius)
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        let angle = atan2(vector.dy, vector.dx) * 180 / .pi
        let normalized = angle < 0 ? angle + 360 : angle
        return Angle(degrees: normalized)
    }
    
    static func defaultBoundsStep(for bounds: ClosedRange<Double>) -> Double {
        let scope = bounds.upperBound - bounds.lowerBound
        let base = pow(10.0, floor(log10(max(scope / 10, 1))))
        return base
    }

    func snapToStep(_ value: Double, for end: Handle) -> Double {
        guard step > 0 else { return value }
        let rounded = (value / step).rounded() * step
        switch end {
        case .start:
            return max(rounded, bounds.lowerBound)
        case .end:
            return min(rounded, bounds.upperBound)
        default:
            return value
        }
    }

    func dragGesture(for handle: Handle) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let angle: Angle = angleFromDrag(location: value.location)
                if draggingHandle == handle || draggingHandle == nil {
                    if let last: Angle = lastHapticAngle {
                        if abs(angle.degrees - last.degrees) > 4 {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            lastHapticAngle = angle
                        }
                    } else {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        lastHapticAngle = angle
                    }
                    var arcMoves: Bool = true
                    var newLower: Double = range.lowerBound
                    var newUpper: Double = range.upperBound
                    if [.start, .arc].contains(handle) {
                        if draggingHandle == nil {
                            startDragOffset = Angle(degrees: angle.degrees - rangeDegrees.lowerBound)
                        }
                        newLower = moveStartHandleResultingInValue(to: angle)
                        arcMoves = arcMoves
                            && newLower != range.lowerBound
                            && newLower > bounds.lowerBound
                    }
                    if [.end, .arc].contains(handle) {
                        if draggingHandle == nil {
                            endDragOffset = Angle(degrees: angle.degrees - rangeDegrees.upperBound)
                        }
                        newUpper = moveEndHandleResultingInValue(to: angle)
                        arcMoves = arcMoves
                            && newUpper != range.upperBound
                            && newUpper < bounds.upperBound
                    }
                    if handle != .arc || arcMoves {
                        newLower = snapToStep(newLower, for: .start)
                        newUpper = snapToStep(newUpper, for: .end)
                        self.range = newLower...newUpper
                    }
                    if draggingHandle == nil {
                        draggingHandle = handle
                    }
                }
            }
            .onEnded { _ in
                draggingHandle = nil
                lastHapticAngle = nil
            }
    }
    
    func moveStartHandleResultingInValue(to angle: Angle) -> Double {
        let raw = angle.degrees - startDragOffset.degrees
        var newDegrees = raw.truncatingRemainder(dividingBy: 360)
        if newDegrees < 0 {
            newDegrees += 360
        }
        if rangeDegrees.lowerBound - boundsDegrees.lowerBound < handleWidth &&
            abs(newDegrees - rangeDegrees.lowerBound) > handleWidth {
            return bounds.lowerBound
        } else if newDegrees >= boundsDegrees.lowerBound &&
                    newDegrees < rangeDegrees.upperBound - handleWidth {
            return valueFromAngle(Angle(degrees: newDegrees))
        } else {
            return range.lowerBound
        }
    }
    
    func moveEndHandleResultingInValue(to angle: Angle) -> Double {
        var newDegrees = angle.degrees - endDragOffset.degrees
        newDegrees = newDegrees.truncatingRemainder(dividingBy: 360)
        if newDegrees < 0 {
            newDegrees += 360
        }
        if boundsDegrees.upperBound - rangeDegrees.upperBound < handleWidth &&
            abs(newDegrees - rangeDegrees.upperBound) > handleWidth {
            return bounds.upperBound
        } else if newDegrees <= boundsDegrees.upperBound &&
                    newDegrees > rangeDegrees.lowerBound + handleWidth {
            return valueFromAngle(Angle(degrees: newDegrees))
        } else {
            return range.upperBound
        }
    }
    
    func angleFromValue(_ value: Double) -> Angle {
        let totalRange = bounds.upperBound - bounds.lowerBound
        let valueOffset = value - bounds.lowerBound
        let fraction = valueOffset / totalRange
        let angleRange = boundsDegrees.upperBound - boundsDegrees.lowerBound
        let degrees = boundsDegrees.lowerBound + fraction * angleRange
        return Angle(degrees: degrees)
    }
    
    func valueFromAngle(_ angle: Angle) -> Double {
        let totalRange = bounds.upperBound - bounds.lowerBound
        let angleRange = boundsDegrees.upperBound - boundsDegrees.lowerBound
        let fraction = (angle.degrees - boundsDegrees.lowerBound) / angleRange
        let value = bounds.lowerBound + fraction * totalRange
        return value
    }
    
    func clampRangeIfNeeded(fromPriorBounds oldBounds: ClosedRange<Double>) {
        var lower = range.lowerBound
        var upper = range.upperBound
        if lower < bounds.lowerBound {
            lower = bounds.lowerBound
        }
        if upper > bounds.upperBound {
            upper = bounds.upperBound
        }
        if lower > upper {
            lower = bounds.lowerBound
            upper = bounds.upperBound
        }
        animateRangeChange(to: lower...upper, fromPriorBounds: oldBounds)
    }

    func animateRangeChange(
        to newRange: ClosedRange<Double>,
        fromPriorBounds oldBounds: ClosedRange<Double>
    ) {
        showSlider = false
        let steps = CircularRangeSlider.sliderAnimationSteps
        let interval = CircularRangeSlider.sliderAnimationDuration / Double(steps)
        let oldTotal = oldBounds.upperBound - oldBounds.lowerBound
        let currentLowerFrac = (range.lowerBound - oldBounds.lowerBound) / oldTotal
        let currentUpperFrac = (range.upperBound - oldBounds.lowerBound) / oldTotal
        let newTotal = bounds.upperBound - bounds.lowerBound
        let targetLowerFrac = (newRange.lowerBound - bounds.lowerBound) / newTotal
        let targetUpperFrac = (newRange.upperBound - bounds.lowerBound) / newTotal
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let easeT = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
            let lowerFrac = currentLowerFrac + (targetLowerFrac - currentLowerFrac) * easeT
            let upperFrac = currentUpperFrac + (targetUpperFrac - currentUpperFrac) * easeT
            let newLower = bounds.lowerBound + lowerFrac * newTotal
            let newUpper = bounds.lowerBound + upperFrac * newTotal
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                self.range = newLower...newUpper
                if i > 1 {
                   showSlider = true
                }
            }
        }
    }
}

#Preview {
    CircularRangeSliderPreview()
}

private struct CircularRangeSliderPreview: View {
    @State private var showSlider: Bool = false
    @State private var rangeUserSelection: ClosedRange<Double>
    @State private var bounds: ClosedRange<Double>
    @State private var circleDiameter: CGFloat = CircularRangeSlider.defaultCircleDiameter
    @State private var arcTrimmingDegrees: CGFloat = CircularRangeSlider.defaultArcTrimmingDegrees
    @State private var trackWidth: CGFloat = CircularRangeSlider.defaultTrackWidth
    @State private var handleWidth: CGFloat = CircularRangeSlider.defaultHandleWidth
    @State private var color: Color
    @State private var step: Double
    
    private let defaultBounds: ClosedRange<Double> = 0.0...999.0

    init() {
        let defaultLower: Double = defaultBounds.upperBound / 6
        let defaultUpper: Double = defaultBounds.upperBound / 3
        _rangeUserSelection = State(initialValue: defaultLower...defaultUpper)
        _bounds = State(initialValue: defaultBounds)
        _step = State(initialValue: CircularRangeSlider.defaultBoundsStep(for: defaultBounds))
        _color = State(initialValue: .accentColor)
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Bounds")) {
                    HStack {
                        Text("Lower")
                        Spacer()
                        TextField(
                            "Lower",
                            value: Binding<Int>(
                                get: {
                                    Int(bounds.lowerBound)
                                },
                                set: {
                                    let newBounds = Double($0)...bounds.upperBound
                                    self.bounds = newBounds
                                    self.step = CircularRangeSlider.defaultBoundsStep(for: newBounds)
                                }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Upper")
                        Spacer()
                        TextField(
                            "Upper",
                            value: Binding<Int>(
                                get: {
                                    Int(bounds.upperBound)
                                },
                                set: {
                                    let newBounds = bounds.lowerBound...Double($0)
                                    self.bounds = newBounds
                                    self.step = CircularRangeSlider.defaultBoundsStep(for: newBounds)
                                }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                }
                Section(header: Text("User selection")) {
                    HStack {
                        Text("Lower")
                        Spacer()
                        TextField(
                            "Lower",
                            value: Binding<Int>(
                                get: {
                                    Int(rangeUserSelection.lowerBound)
                                },
                                set: {
                                    self.rangeUserSelection = Double($0)...rangeUserSelection.upperBound
                                }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Upper")
                        Spacer()
                        TextField(
                            "Upper",
                            value: Binding<Int>(
                                get: {
                                    Int(rangeUserSelection.upperBound)
                                },
                                set: {
                                    self.rangeUserSelection = rangeUserSelection.lowerBound...Double($0)
                                }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                }
                Section(header: Text("Precision")) {
                    HStack {
                        Text("Step length")
                        Spacer()
                        TextField(
                            "Step",
                            value: Binding<Int>(
                                get: { Int(step) },
                                set: { self.step = Double($0) }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                }
                Section(header: Text("Appearance")) {
                    ColorPicker("Slider color", selection: $color)
                    HStack {
                        Text("Circle track diameter")
                        Spacer()
                        TextField(
                            "Pixels",
                            value: Binding<Int>(
                                get: { Int(circleDiameter) },
                                set: { self.circleDiameter = CGFloat($0) }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Circle track width")
                        Spacer()
                        TextField(
                            "Pixels",
                            value: Binding<Int>(
                                get: { Int(trackWidth) },
                                set: { self.trackWidth = Double($0) }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Handle width")
                        Spacer()
                        TextField(
                            "Pixels",
                            value: Binding<Int>(
                                get: { Int(handleWidth) },
                                set: { self.handleWidth = CGFloat($0) }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Arc trimming size")
                        Spacer()
                        TextField(
                            "Degrees",
                            value: Binding<Int>(
                                get: { Int(arcTrimmingDegrees) },
                                set: { self.arcTrimmingDegrees = CGFloat($0) }
                            ),
                            format: IntegerFormatStyle().grouping(.never)
                        )
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Show circular range slider") {
                        showSlider = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $showSlider) {
            NavigationStack {
                ZStack {
                    CircularRangeSlider(
                        range: $rangeUserSelection,
                        bounds: bounds,
                        circleDiameter: circleDiameter,
                        arcTrimmingDegrees: arcTrimmingDegrees,
                        trackWidth: trackWidth,
                        handleWidth: handleWidth,
                        color: color,
                        step: step
                    )
                    VStack {
                        Text(String(format: "%.1f", rangeUserSelection.lowerBound))
                            .bold()
                            .font(.system(size: 24))
                        Image(systemName: "arrow.up.arrow.down")
                            .padding(.vertical, 0.25)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", rangeUserSelection.upperBound))
                            .bold()
                            .font(.system(size: 24))
                    }
                }
                .navigationTitle("Circular range slider")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Settings") {
                            self.showSlider.toggle()
                        }
                    }
                }
            }
            .presentationDetents([.height(420)])
            .background(Color(uiColor: .systemBackground))
        }
    }
}
