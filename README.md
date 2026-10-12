# sidecarctl

A command-line tool for macOS that starts and ends Sidecar sessions to an iPad,
chooses whether the session runs over the cable or Wi-Fi, and can route the
session through a virtual display, which may make the iPad more responsive.

macOS has no public API for starting Sidecar. sidecarctl drives the private
`SidecarCore` framework, following the approach of
[SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher), and uses
CoreGraphics' undeclared `CGVirtualDisplay` classes for the boost.
A macOS update can break either.

## Status

Tested on macOS 27.0 on Apple silicon with an iPad Pro 13-inch (M4). Other
iPads and other macOS versions are untested. Intel Macs are not supported.

## Build

Needs Apple's command line tools (`xcode-select --install`).

```sh
xcrun swift build -c release
```

The binary is `.build/release/sidecarctl`. Copy it anywhere on your `PATH`.

## Usage

```
sidecarctl devices [--verbose]
sidecarctl connect [<device>] [--connection <prefer-wired | wired | wireless | system>]
                   [--framerate <fps>] [--low-latency] [--ignore-not-ready]
                   [--retries <count>] [--boost [--hz <rate>] [--retina]]
sidecarctl disconnect [<device>]
sidecarctl boost [--hz <rate>] [--retina]
sidecarctl boost --stop
```

### Devices

`devices` prints each reachable iPad on its own line as its UUID, a tab, and its
name. `--verbose` adds a tab and the status value Sidecar reports for it.

`connect` and `disconnect` take a device as either its name or its UUID, without
regard to case. With one iPad reachable the device can be left out.

### Connecting

`--connection` selects how the session is carried:

| Value | Behavior |
|---|---|
| `prefer-wired` | The default. Over the cable when an iPad is attached by USB. Over Wi-Fi when none is attached or when the cable does not connect in two tries. |
| `wired` | Over the cable. Exits 8 when no iPad is attached by USB. |
| `wireless` | Over Wi-Fi. |
| `system` | Whichever Sidecar picks. |

A session that already matches what was asked for is kept, and `connect` exits 0.
A session over a different transport or at a different framerate is ended and
replaced. `disconnect` also exits 0 when there is no session to end.

`--framerate` sets the rate Sidecar streams at, 60 when left out. `--low-latency`
turns on Sidecar's low latency mode.

### When the iPad is not ready

An iPad can be listed by `devices` and still refuse the connection, as one that
has sat unused for a while may, and macOS shows a dialog of its own for each
refused attempt. To avoid that dialog, `connect` first reads the status value
Sidecar reports for the iPad. When it is one recorded as not ready, `connect`
exits 9 without asking Sidecar. Wake and unlock the iPad and run `connect` again,
or pass `--ignore-not-ready` to attempt the connection anyway.

`--retries <count>` allows that many further tries, 3 seconds apart. It is 0
unless given, since each try that fails shows another dialog. While the iPad
reports a recorded not-ready value a try only reads the value again, which shows
no dialog, so `--retries 10` gives about half a minute to wake an iPad.

The check does not catch every refusal. What puts an iPad into the recorded state
is not known, and a connection can still fail, with its dialog, from a state that
reports as ready.

Only status values seen on a real device are recorded, and any other value is
attempted as usual, so an iPad that reports differently is never refused. The
recorded values so far come from one iPad model. If `connect` fails on your iPad
with a dialog, the output of `sidecarctl devices --verbose` at that moment is the
value to report.

### Boost

`boost` creates a virtual display and has Sidecar's display mirror it. The
virtual display is set to a higher refresh rate than Sidecar's own, so the Mac
draws at that rate and Sidecar streams what it drew. `--retina` also moves the
display to its Retina mode at the same size.

On my iPad Pro 13-inch (M4) this made Sidecar noticeably more responsive. It is
not a promise of any particular refresh rate on the iPad. What
reaches the screen depends on the iPad, the Mac, the connection, and the macOS
version, none of which sidecarctl can measure, and the result may be no
different from plain Sidecar. Try it, and stop using it if it does not help.

`boost` needs a Sidecar session to be running. It keeps running until the
session ends or `sidecarctl boost --stop` is run, and the mirroring ends with it.

`connect --boost` does both in one command: it starts the session, or keeps one
that already matches, then runs the boost on it, taking `--hz` and `--retina`. The
command keeps running for the life of the session. The two end together: when the
session ends the boost stops, and when the boost is stopped, with
`sidecarctl boost --stop` or by interrupting the command, the session is ended
too. If the boost cannot be set up the command exits with the boost's error and
the session is left running as plain Sidecar.

`--hz` sets the rate the virtual display is created at, 120 unless given. That
is the rate the Mac draws at. Nothing on the Mac reports what the iPad itself
can show, so the rate is not checked against it, and what the iPad shows may be
lower.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | Bad arguments |
| 2 | No reachable devices, or no Sidecar display for `boost` |
| 3 | No device with that name or UUID |
| 4 | SidecarCore or CoreGraphics reported an error |
| 5 | SidecarCore could not be loaded |
| 6 | No device given and more than one reachable |
| 7 | A boost is already running |
| 8 | The connection asked for is unavailable |
| 9 | The device reports it is not ready |

## Tests

The unit tests cover argument parsing, device matching, and which connections are
tried in what order. With Xcode selected (`xcode-select -p` names Xcode.app):

```sh
xcrun swift test
```

With only the command line tools, the test macros' plugin has to be pointed at:

```sh
xcrun swift test -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

`scripts/device-test.sh` runs the built binary against a real iPad. It needs one
reachable iPad, unlocked and awake, and it starts and ends Sidecar sessions.

## License

MIT. See [LICENSE](LICENSE).
