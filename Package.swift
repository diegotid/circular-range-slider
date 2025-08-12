// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CircularRangeSlider",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CircularRangeSlider",
            targets: ["CircularRangeSlider"]),
    ],
    targets: [
        .target(
            name: "CircularRangeSlider"),
        .testTarget(
            name: "CircularRangeSliderTests",
            dependencies: ["CircularRangeSlider"]
        ),
    ]
)
