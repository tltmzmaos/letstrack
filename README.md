# Let's Track

A simple and intuitive expense tracking app for iOS.

## Features

- **Dashboard**: View your total balance, monthly income/expense summary, and recent transactions at a glance
- **Transaction Management**: Add, edit, and delete income/expense transactions with categories
- **Voice Entry**: Add transactions using voice recognition (Korean & English supported)
- **Calendar View**: Browse transactions by date with a visual calendar
- **Map View**: See where you spent money with location-tagged transactions
- **Insights**: Analyze spending trends, category breakdowns, and recurring patterns
- **Budget Management**: Set monthly budgets per category and track your progress
- **Savings Goals**: Create and track savings goals with visual progress
- **Recurring Transactions**: Automate regular expenses like subscriptions and rent
- **Tags**: Organize transactions with custom tags
- **Multi-Currency**: Support for KRW, USD, EUR, JPY, CNY, GBP
- **Localization**: Full support for English and Korean
- **Security**: Face ID / Touch ID app lock
- **Data Management**: Export to CSV, backup/restore functionality
- **Notifications**: Daily reminders, budget alerts, weekly spending reports
- **Performance**: Preloaded categories/tags, cached calendar summaries, daily index caching, map annotations caching, debounced search, optimized statistics/insights

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Architecture

The app follows Clean Architecture with MVVM pattern:

```
├── Application/        # App entry point, ContentView
├── Domain/            # Models and Use Cases
├── Data/              # Repositories and Data Sources
├── Infrastructure/    # Services (Notification, Location, Backup, etc.)
├── Presentation/      # Views, ViewModels, Components
├── Resources/         # Localization, Assets
└── Widget/           # Home screen widget
```

## Tech Stack

- **SwiftUI** - Declarative UI framework
- **SwiftData** - Persistence framework
- **MapKit** - Map integration
- **Speech** - Voice recognition
- **LocalAuthentication** - Biometric authentication
- **WidgetKit** - Home screen widgets

## Release Prep

- Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`
- Set `DEVELOPMENT_TEAM` and confirm bundle identifiers
- Run tests and a Release build/archive in Xcode
- Validate App Icon and localized metadata
- Verify backup/restore and core flows on a real device

## App Store

Available on the App Store: https://apps.apple.com/app/id1497482833

## Version History

- **v1.0** (Feb 2020): Initial release with basic expense tracking
- **v2.0** (Dec 2025): Complete rewrite with SwiftUI, SwiftData, voice entry, maps, insights, and more

## License

All rights reserved.
