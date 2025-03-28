# FileGhost - Secure File Hider 🔒👻


A secure mobile application that hides and protects your sensitive files with PIN or biometric authentication. Built with Flutter for cross-platform compatibility.

## Features ✨

- 🔒 **Secure Authentication**: PIN protection + biometric unlock (fingerprint/face ID)
- 👻 **Stealth Mode**: Files are hidden in a secure directory with `.nomedia`
- 📁 **File Management**: Hide, view, and delete files securely
- 🎨 **Beautiful UI**: Dark theme with smooth animations and transitions
- 🔄 **Easy Import**: Select files directly from your device storage
- 🚫 **No Ads**: Completely ad-free experience


## Installation ⚙️

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio/Xcode (for emulator/device testing)

### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/technolenz/fileghost.git
   ```
2. Navigate to project directory:
   ```bash
   cd fileghost
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Dependencies 📦

- `file_picker`: For selecting files to hide
- `flutter_secure_storage`: For securely storing PIN
- `local_auth`: For biometric authentication
- `path_provider`: For accessing device storage
- `permission_handler`: For managing storage permissions
- `page_transition`: For beautiful screen transitions
- `google_fonts`: For custom typography

## Usage Guide 📖

1. **First Launch**:
   - Set up your 4-digit PIN
   - Enable biometric authentication if desired

2. **Hiding Files**:
   - Tap the "+" button
   - Select files from your device
   - Files are automatically secured

3. **Accessing Files**:
   - Enter your PIN or use biometrics
   - View all hidden files in the secure vault
   - Tap files to preview (if supported)

4. **Deleting Files**:
   - Long-press to select files
   - Tap trash icon to delete permanently

## Security Details 🔐

- Files are stored in app's private directory (`/data/data/com.technolenz.fileghost`)
- `.nomedia` file prevents media scanning
- PIN is encrypted using Flutter Secure Storage
- No internet permissions - works completely offline

## Contributing 🤝

Contributions are welcome! Please follow these steps:


## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support ☕

If you find this project useful, consider starring the repo and or linking me up for jobs

Made with ❤️ and Flutter