# RunAI Coach

A comprehensive running companion app that tracks and analyzes your running metrics in real-time using Apple Watch and iPhone.

## Features

- Real-time metric tracking during workouts
- Voice feedback on your performance
- Elevation tracking using barometric pressure
- Seamless integration between Apple Watch and iPhone
- Comprehensive health metrics collection

## Metrics

| **Metric**         | **Units** | **Source** | **Description**                                |
|--------------------|-----------|------------|------------------------------------------------|
| Heart Rate         | BPM       | Watch      | Real-time heart rate monitoring                |
| Distance           | m         | Watch      | Total distance covered during the workout      |
| Step Count         | count     | Watch      | Number of steps taken                          |
| Active Energy      | kcal      | Watch      | Calories burned during the workout             |
| Elevation          | m         | Phone      | Elevation change via barometric pressure       |
| Running Power      | W         | Watch      | Instantaneous running power output             |
| Running Speed      | m/s       | Watch      | Current running speed                          |

## Requirements

- iOS 15.0+
- watchOS 8.0+
- Xcode 13.0+
- Swift 5.5+

## Privacy

The app requires the following permissions:
- HealthKit access for workout metrics
- Motion data for elevation tracking
- Location services for outdoor workouts
