# Running on a physical Android phone

## Install the ready-to-use app

Requires Android 7.0 / API 24 or later.

1. On your computer, find `artifacts/CurrencyInsights-Android.apk` in the lab folder.
2. Connect the phone to your computer with a USB cable. In the phone's USB notification, select **File transfer**.
3. Copy the APK to the phone's **Download** folder. You can also transfer the file through cloud storage.
4. On the phone, open **Files → Downloads**, tap the APK, and select **Install**.
5. If Android asks for permission, allow installation from this source for the selected file manager. The setting's name depends on the manufacturer.
6. Launch the installed app. The first exchange-rate download requires internet access; downloaded data is saved for offline use.

This method does not require Flutter, Android Studio, or developer mode on
the phone. Once installed, the app runs independently and you can disconnect
the computer. The APK is a release build signed with a debug key for this lab.

If Android offers to update an existing installation, accept: the cache is
preserved when signatures are compatible. If it reports a signature conflict,
avoid uninstalling the old version unnecessarily: uninstalling also deletes
its local cache.

## Run from VS Code while editing code

1. On the phone, open **Settings → About phone → Build number** and tap it seven times. On Samsung devices, Build number is usually under **Software information**. The location may vary.
2. Open the newly available **Developer options** section and enable **USB debugging**.
3. Connect the phone using a cable that supports data transfer. Unlock the screen and approve the **Allow USB debugging** prompt for your computer.
4. Open the lab folder in VS Code. In the PowerShell terminal, run:

```powershell
# Run from the repository root.
& 'C:\Users\SamirPula\flutter\bin\flutter.bat' pub get
& 'C:\Users\SamirPula\flutter\bin\flutter.bat' devices
```

Find the entry for your phone. Copy its ID and substitute it for `PHONE_ID`:

```powershell
& 'C:\Users\SamirPula\flutter\bin\flutter.bat' run -d PHONE_ID
```

Do not use `emulator-5554`: that is the emulator's ID. While the command is
running, press `r` in the terminal to apply Dart changes through hot reload,
`R` to restart the app, or `q` to end the run session. With the Flutter/Dart
extensions installed, you can also select the phone in VS Code's status bar
and press **F5**.

## If the phone does not appear

Check the connection:

```powershell
& 'C:\Users\SamirPula\AppData\Local\Android\Sdk\platform-tools\adb.exe' devices -l
```

- `unauthorized`: unlock the phone and approve the computer's authorization prompt; reconnect the cable if needed.
- Empty list: try a data-capable cable, another USB port, and **File transfer** mode. Some phones require the manufacturer's official OEM USB driver on Windows.
- Flutter not found: use the full path to `flutter.bat`, as in the commands above.

## Rebuild the APK after changing source files

From the project folder:

```powershell
.\scripts\build-apk.ps1 -Flutter 'C:\Users\SamirPula\flutter\bin\flutter.bat'
```

The new APK appears at the same path: `artifacts/CurrencyInsights-Android.apk`.
The script includes the illustration from `assets/` and builds in a temporary
directory without Cyrillic characters. The APK and SDK are not stored in Git:
after downloading the source from GitHub, build the APK first.

Official instructions: [physical Android device setup](https://developer.android.com/studio/run/device),
[developer options](https://developer.android.com/studio/debug/dev-options),
[Flutter for Android](https://docs.flutter.dev/platform-integration/android/setup).
