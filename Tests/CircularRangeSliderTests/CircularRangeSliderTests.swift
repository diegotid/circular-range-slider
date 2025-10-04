import Testing
import SwiftUI
@testable import CircularRangeSlider

@Suite("CircularRangeSlider Logic")
struct CircularRangeSliderLogicTests {
    @Test("angleFromValue and valueFromAngle round-trip mapping")
    @MainActor
    func testAngleValueMapping() throws {
        let bounds = 0.0...100.0
        // Dummy binding not used directly here
        let dummy = Binding.constant(bounds)
        let slider = CircularRangeSlider(
            range: dummy,
            bounds: bounds,
            circleDiameter: 200,
            arcTrimmingDegrees: 60
        )
        // Test edge mapping
        let lowerAngle = slider.angleFromValue(bounds.lowerBound)
        let upperAngle = slider.angleFromValue(bounds.upperBound)
        #expect(abs(slider.valueFromAngle(lowerAngle) - bounds.lowerBound) < 1e-6)
        #expect(abs(slider.valueFromAngle(upperAngle) - bounds.upperBound) < 1e-6)
        // Test middle
        let midValue = (bounds.lowerBound + bounds.upperBound) / 2
        let midAngle = slider.angleFromValue(midValue)
        #expect(abs(slider.valueFromAngle(midAngle) - midValue) < 1e-6)
    }

    @Test("CircularRangeSlider initializes with correct defaults")
    @MainActor
    func testInitialization() throws {
        let bounds = 0.0...100.0
        let range = 10.0...50.0
        let binding = Binding.constant(range)

        let slider = CircularRangeSlider(
            range: binding,
            bounds: bounds
        )

        // Test that slider initializes without crashing
        #expect(slider.bounds == bounds)
        #expect(slider.circleDiameter == CircularRangeSlider.defaultCircleDiameter)
        #expect(slider.arcTrimmingDegrees == CircularRangeSlider.defaultArcTrimmingDegrees)
        #expect(slider.trackWidth == CircularRangeSlider.defaultTrackWidth)
        #expect(slider.handleWidth == CircularRangeSlider.defaultHandleWidth)
    }

    @Test("CircularRangeSlider with custom parameters")
    @MainActor
    func testCustomParameters() throws {
        let bounds = 0.0...100.0
        let range = 10.0...50.0
        let binding = Binding.constant(range)

        let customDiameter: CGFloat = 300
        let customArcTrimming: CGFloat = 90
        let customTrackWidth: CGFloat = 50
        let customHandleWidth: CGFloat = 40
        let customStep: Double = 5

        let slider = CircularRangeSlider(
            range: binding,
            bounds: bounds,
            circleDiameter: customDiameter,
            arcTrimmingDegrees: customArcTrimming,
            trackWidth: customTrackWidth,
            handleWidth: customHandleWidth,
            step: customStep
        )

        #expect(slider.circleDiameter == customDiameter)
        #expect(slider.arcTrimmingDegrees == customArcTrimming)
        #expect(slider.trackWidth == customTrackWidth)
        #expect(slider.handleWidth == customHandleWidth)
        #expect(slider.step == customStep)
    }

    @Test("CircularRangeSlider with markers")
    @MainActor
    func testMarkersInitialization() throws {
        let bounds = 0.0...100.0
        let range = 10.0...50.0
        let binding = Binding.constant(range)
        let markers = [20.0, 40.0, 60.0, 80.0]

        let slider = CircularRangeSlider(
            range: binding,
            bounds: bounds,
            markers: markers
        )

        #expect(slider.markers == markers)
    }

    @Test("CircularRangeSlider view renders without crashing")
    @MainActor
    func testViewRendering() throws {
        let bounds = 0.0...100.0
        let range = 10.0...50.0
        let binding = Binding.constant(range)

        let slider = CircularRangeSlider(
            range: binding,
            bounds: bounds
        )

        // Test that the view can be created and body computed
        let body = slider.body
        #expect(body != nil)
    }

    @Test("CircularRangeSlider with marker labels")
    @MainActor
    func testMarkerLabels() throws {
        let bounds = 0.0...100.0
        let range = 10.0...50.0
        let binding = Binding.constant(range)
        let markers = [25.0, 50.0, 75.0]

        let slider = CircularRangeSlider(
            range: binding,
            bounds: bounds,
            markers: markers,
            markerLabel: { value in
                AnyView(Text("\(Int(value))"))
            }
        )

        #expect(slider.markers == markers)
        #expect(slider.markerLabel != nil)
    }
}
