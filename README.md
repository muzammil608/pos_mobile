# ShopFlow POS

ShopFlow POS (Flutter + PocketBase).

## Local PocketBase

Start the local backend before running the Flutter app:

```sh
./pocketbase serve
```

The app defaults to `http://127.0.0.1:8090`.

For VS Code Android phone debugging, use the `POS Mobile Debug` launch profile.
It runs `adb reverse tcp:8090 tcp:8090` before launch so the physical phone can
reach the PocketBase server running on this computer.

If you run from the terminal instead of VS Code, run this once after connecting
the phone:

```sh
adb reverse tcp:8090 tcp:8090
```

For another backend host, pass it explicitly:

```sh
flutter run --dart-define=POCKETBASE_URL=http://YOUR_HOST:8090
```
