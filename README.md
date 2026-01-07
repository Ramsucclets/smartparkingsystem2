# Smart Parking System

Flutter-based frontend application for a real-time parking management system. Provides parking spot visualization, pathfinding navigation, and admin tools for grid configuration.

## Features

### User Features

- **Authentication** - Login, registration, password reset via AWS Amplify Cognito
- **Parking Map** - Interactive grid-based map with zoom/pan, real-time spot status visualization
- **Pathfinding Navigation** - A\* algorithm-based turn-by-turn navigation to selected spots (WIP)
- **Spot Watch** - Multi-spot monitoring with historical usage statistics
- **Statistics Dashboard** - Parking usage analytics with filtering and sorting

### Admin Features

- **Grid Designer** - Visual editor for parking lot layout (spots, roads, entrances, obstacles)
- **User Management** - View and manage registered users
- **System Logs** - Filterable activity and error logging

## Tech Stack

| Component        | Technology                         |
| ---------------- | ---------------------------------- |
| Framework        | Flutter (Dart)                     |
| Auth             | AWS Amplify Cognito                |
| Database         | AWS DynamoDB                       |
| State Management | setState, Provider (ThemeProvider) |
| Platforms        | Android, iOS, Windows, Web         |

## Project Structure

```
lib/
├── main.dart                          # App entry point, Amplify configuration
├── models/
│   ├── parking_spot.dart              # Parking spot data model
│   ├── parking_grid.dart              # Grid serialization/deserialization
│   ├── entrance.dart                  # Entrance element model
│   ├── obstacle.dart                  # Obstacle element model
│   ├── road.dart                      # Road element model
│   └── system_log.dart                # System log entry model
├── screens/
│   ├── login_screen.dart              # User authentication
│   ├── register_screen.dart           # New user registration
│   ├── confirm_signup_screen.dart     # Email verification
│   ├── resetpassword_screen.dart      # Password reset request
│   ├── confirm_reset_password_screen.dart  # Password reset confirmation
│   ├── home_screen.dart               # Main dashboard
│   ├── map.dart                       # Parking map with navigation
│   ├── statistics_screen.dart         # Usage analytics
│   ├── spot_watch_screen.dart         # Multi-spot monitoring
│   ├── setting_screen.dart            # User preferences
│   ├── admin_screen.dart              # Admin panel hub
│   ├── wip_screen.dart                # Placeholder screen
│   └── admin/
│       ├── grid_designer_screen.dart  # Parking lot layout editor
│       ├── grid_painter.dart          # Canvas rendering for grid
│       ├── designer_toolbar.dart      # Grid editor tools
│       ├── properties_panel.dart      # Element property editor
│       ├── grid_designer_io.dart      # Platform-specific I/O (mobile)
│       ├── grid_designer_web.dart     # Platform-specific I/O (web)
│       ├── user_management_screen.dart  # User administration
│       └── system_logs_screen.dart    # Log viewer
├── services/
│   ├── auth_service.dart              # Amplify auth wrapper
│   ├── dynamodb_service.dart          # DynamoDB data operations
│   ├── logging_service.dart           # System logging singleton
│   ├── theme_provider.dart            # Dark/light theme state
│   ├── admin_router.dart              # Admin navigation routes
│   └── amplifyconfiguration.dart      # AWS Amplify config
├── widgets/
│   ├── animated_gradient_background.dart  # Animated gradient widget
│   ├── glassmorphic_card.dart         # Glass-effect card component
│   ├── scale_button.dart              # Animated button with scale effect
│   ├── fade_slide_transition.dart     # Staggered fade/slide animation
│   ├── stat_card.dart                 # Statistics display card
│   └── navigation.dart                # Navigation helper
└── utils/
    └── pathfinder.dart                # A* pathfinding implementation
```

## Setup

### Requirements

- Flutter SDK 3.6.1+
- Dart SDK
- AWS Account (for Amplify)

### Installation

```bash
git clone https://github.com/yourusername/smartparkingsystem.git
cd smartparkingsystem
flutter pub get
```

### AWS Configuration

Amplify configuration is stored in `lib/services/amplifyconfiguration.dart`. Update with your Cognito User Pool and DynamoDB credentials, or run:

```bash
amplify init
amplify add auth
amplify push
```

### Run

```bash
flutter run
```

## Architecture

Part of an IoT smart parking solution:

1. **Sensors** - ESP32 with ToF/mmWave sensors, camera-based detection
2. **Edge Processing** - Local server running YOLOv8 vehicle detection
3. **Backend** - AWS DynamoDB for real-time state storage
4. **Frontend** (this repo) - Flutter app subscribing to database updates

## License

MIT License - see [LICENSE](LICENSE)
