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

## Aggregates

For details on the aggregates refer to `AGGREGATES.md`.

## Requirements

- iOS 15.0+
- watchOS 8.0+
- Xcode 13.0+
- Swift 5.5+
- OpenAI API key for voice feedback

## Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/RunAICoach.git
cd RunAICoach
```

2. Run the setup command:
```bash
make setup
```

3. Add your OpenAI API key:
   - Open `RunAICoach/Info.plist`
   - Replace `YOUR_API_KEY_HERE` with your actual OpenAI API key

4. Open the project in Xcode:
```bash
open RunAICoach.xcodeproj
```

5. Build and run the project

## Privacy

The app requires the following permissions:
- HealthKit access for workout metrics
- Motion data for elevation tracking
- Location services for outdoor workouts
