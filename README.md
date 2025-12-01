# Smart Parking System App

A modern Flutter application designed to help users find and navigate to available parking spots in real-time. This application serves as the frontend interface for a larger Smart Parking System ecosystem.

## 📱 Features

*   **User Authentication**: Secure login, registration, and password recovery powered by **AWS Amplify Cognito**.
*   **Real-time Parking Map**: Visual representation of parking spots (Available/Occupied) overlaid on a parking lot map.
*   **Navigation Assistance**: Turn-by-turn instructions to guide the user to their selected parking spot.
*   **Statistics Dashboard**: View parking usage statistics (UI implementation).
*   **Settings**: User preferences and account management.

## 🛠 Tech Stack

*   **Frontend Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **Authentication**: [AWS Amplify](https://docs.amplify.aws/) (Cognito)
*   **State Management**: `setState` (currently), transitioning to Riverpod/Provider as needed.
*   **Platforms**: Android, iOS, Windows, Web.

## 🚀 Getting Started

### Prerequisites

*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.6.1 or later)
*   [Dart SDK](https://dart.dev/get-dart)
*   An AWS Account (for Amplify configuration)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/smartparkingsystem.git
    cd smartparkingsystem
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure AWS Amplify:**
    *   The project currently uses a hardcoded Amplify configuration in `lib/main.dart`.
    *   For your own setup, run `amplify init` and `amplify add auth` using the Amplify CLI, or update the configuration string in `_configureAmplify()` with your own Cognito User Pool details.

4.  **Run the app:**
    ```bash
    flutter run
    ```

## 📂 Project Structure

```
lib/
├── main.dart           # Entry point & Amplify Configuration
├── screens/            # UI Screens
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── map.dart        # Parking Map & Navigation Logic
│   └── ...
├── widgets/            # Reusable UI Components
├── services/           # Authentication & Data Services
└── ...
```

## 🏗 System Architecture (Context)

This application is designed to work as part of a complete IoT Smart Parking solution. While this repository contains the **Frontend Application**, the full system typically includes:

1.  **Embedded Layer**: ESP32 sensors (ToF, mmWave) and Cameras detecting parking occupancy.
2.  **Edge Processing**: A local server (Python) processing sensor data and running YOLOv8 for vehicle detection.
3.  **Backend Layer**: A cloud database (e.g., Supabase or AWS DynamoDB) storing real-time state.
4.  **Frontend Layer (This Repo)**: The mobile/desktop app that subscribes to database updates to show real-time availability.

*Note: The current version of the app uses mock data for the map to demonstrate UI and navigation logic.*

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
