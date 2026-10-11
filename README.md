# Move

A small Windows tray app that reminds you to get up and move. After an hour at your computer it pops up a quick exercise (jumping jacks, squats, push-ups, a wall sit and more) and cycles to a new one each time.

## Features

- **Centered reminder popup** with the exercise, how many reps or seconds, and a form tip. Done, Snooze, or Skip.
- **Built-in timer** for timed exercises like the wall sit and stretch.
- **Game friendly.** When a fullscreen game or video is in front, Move plays three bells and shows the exercise in a small corner notice that you can click through, instead of the popup.
- **Two timer modes.** Restart the countdown when you step away from the keyboard, or keep a fixed schedule.
- **Snooze and pause** from the popup or the tray menu (30 minutes, 1 hour, 2 hours, until tomorrow, or until you resume).
- **Active hours**, so reminders only happen during the part of the day you choose.
- **Your own exercise list.** Add, edit, reorder, remove, or shuffle exercises.
- Follows the Windows light or dark theme and can start when you sign in.

## Install

Download `Move-<version>-x64.msi` from the [latest release](https://github.com/berkpolatCE/Move/releases/latest) and run it. It installs for your user account only, so no administrator rights are needed, and it doesn't need .NET installed.

The installer isn't code-signed, so Windows SmartScreen may warn you the first time. Choose **More info** and then **Run anyway**.

Move appears in the system tray. Click the icon to see what's next, pause reminders, or open settings. Settings are stored in `%AppData%\Move`.

## Build from source

Requires the [.NET 10 SDK](https://dotnet.microsoft.com/download) on Windows.

```powershell
dotnet run --project src/Move
```

Run the tests:

```powershell
dotnet test
```

Build the installer (output goes to `artifacts\installer`). The version comes from `Directory.Build.props`.

```powershell
.\installer\build.ps1
```

## License

[MIT](LICENSE)
