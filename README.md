# sidecarctl

Start and stop Sidecar from the command line.

Sidecar turns an iPad into a second display for a Mac, and macOS only offers it
through menus. sidecarctl lets a script or a keyboard shortcut do the
connecting, and choose between the cable and Wi-Fi.

```sh
sidecarctl connect
```

It can also route the session through a virtual display. In my own use, on an
iPad Pro 13-inch (M4), that made Sidecar noticeably more responsive than it is
out of the box. Whether it does the same for you depends on your iPad and your
Mac, and it may change nothing. See [Boost](#boost) before expecting anything
from it.

## What it does

- Connects and disconnects Sidecar without touching a menu.
- Chooses the connection: cable only, Wi-Fi only, or cable when there is one.
- Optionally routes the session through a virtual display, which may make the
  iPad more responsive.
- Reports what is running, as text or JSON, with exit codes a script can rely on.

## Requirements

- A Mac with Apple silicon. Intel Macs are not supported.
- macOS 27. Other versions are untested.
- An iPad that already works with Sidecar on this Mac. If Sidecar does not
  connect from Control Center, it will not connect from here either.

sidecarctl uses two parts of macOS that Apple does not document: the
`SidecarCore` framework, following the approach of
[SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher), and
CoreGraphics' virtual display classes. A macOS update can break either one. If
the tool stops working after an update, check for a newer release, and open an
issue with the output of `sw_vers` if there is none.

Tested with an iPad Pro 13-inch (M4). Other iPads are untested.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install tsilenzio/tap/sidecarctl
```

Or download the zip from the
[releases page](https://github.com/tsilenzio/sidecarctl/releases), unzip it, and
move `sidecarctl` somewhere on your `PATH`. The binary is signed and notarized.

To build it yourself, see [Building](#building).

## Quick start

See which iPads the Mac can reach:

```
$ sidecarctl devices
11111111-1111-1111-1111-111111111111	Test iPad
```

Connect. With one iPad reachable there is no need to name it:

```sh
sidecarctl connect
```

Disconnect:

```sh
sidecarctl disconnect
```

## Common tasks

**Connect through a virtual display**, which may make the iPad more responsive.
The command keeps running for as long as the session lasts. Press Ctrl-C, or run
`sidecarctl boost --stop` from elsewhere, and the session ends with it.

```sh
sidecarctl connect --boost
```

**Use the cable or nothing.** Exits 8 if no iPad is plugged in.

```sh
sidecarctl connect --connection wired
```

**Use Wi-Fi even when the cable is in.**

```sh
sidecarctl connect --connection wireless
```

**Pick one iPad out of several**, by name or by the UUID from `devices`. A UUID
stays usable in a script without the iPad's name appearing in it.

```sh
sidecarctl connect "Test iPad"
sidecarctl connect 11111111-1111-1111-1111-111111111111
```

**Sharper text with a boost.** `--retina` doubles the pixels each way, which is
four times the pixels for the Mac to draw and send.

```sh
sidecarctl connect --boost --retina
```

**Give a sleeping iPad time to wake.** Checks again every 3 seconds, up to 10
more times.

```sh
sidecarctl connect --retries 10
```

**See what is running.**

```
$ sidecarctl status
connected to Test iPad, wired, 60 fps
boost running
```

**Boost a session that is already running**, such as one started from Control
Center. Here stopping the boost leaves the session up.

```sh
sidecarctl boost
```

## Reference

```
sidecarctl devices [--verbose | --json]
sidecarctl status [--json]
sidecarctl connect [<device>] [--connection <prefer-wired | wired | wireless | system>]
                   [--framerate <fps>] [--low-latency] [--ignore-not-ready]
                   [--retries <count>] [--boost [--hz <rate>] [--retina]]
sidecarctl disconnect [<device>]
sidecarctl boost [--hz <rate>] [--retina]
sidecarctl boost --stop
sidecarctl help [<command>]
sidecarctl --version
```

`sidecarctl help` describes each command, and `sidecarctl help connect`, or
`--help` on any command, explains that one and its options.

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
A session over a different connection or at a different framerate is ended and
replaced. `disconnect` also exits 0 when there is no session to end.

`--framerate` sets the rate Sidecar streams at, 60 when left out. `--low-latency`
turns on Sidecar's low latency mode.

`--retries <count>` allows that many further tries, 3 seconds apart. It is 0
unless given. See [Troubleshooting](#troubleshooting) for why.

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

While a boost runs, macOS lists one more display, named after the iPad. It can
be arranged in System Settings like any other, and macOS remembers where it was
put.

### Calling it from another program

`status` reports what is running, with or without a reachable iPad.

`devices --json` and `status --json` print one line of JSON, so a caller reads
fields and does not parse messages:

```
$ sidecarctl devices --json
[{"connected":true,"id":"11111111-1111-1111-1111-111111111111","name":"Test iPad","notReady":false,"status":"0x1880306"}]
$ sidecarctl status --json
{"boost":4242,"sessions":[{"connection":"wired","displayID":34,"framerate":60,"id":"11111111-1111-1111-1111-111111111111","lowLatency":false,"name":"Test iPad"}]}
```

`boost` is the process ID of the running boost. `connection` is `wired` or
`wireless`. A field with no value is left out, so `boost` is absent when none is
running. A field keeps its name and meaning from one release to the next, and new
fields may be added.

An option the tool does not know is an error, exit 1, and is never read as a
device's name.

### Exit codes

A code keeps its meaning from one release to the next.

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

## Troubleshooting

### macOS shows a "device not found" or "unable to connect" dialog

Those dialogs come from macOS, one for each connection attempt Sidecar refuses,
and sidecarctl cannot turn them off. It tries to avoid causing them:

- Retries are off unless `--retries` is given, since each failed try is another
  dialog.
- Before connecting, `connect` reads the status value Sidecar reports for the
  iPad. When it is one recorded as not ready, `connect` exits 9 without asking
  Sidecar, so no dialog appears.

### `connect` exits 9, "reports it is not ready"

The iPad is listed but would refuse the connection, as one that has sat unused
for a while may. Wake and unlock it and run `connect` again, or use
`--retries 10` to keep checking for about half a minute. A check costs no dialog.
`--ignore-not-ready` attempts the connection anyway.

### `connect` fails though the iPad looks ready

The not-ready check does not catch every refusal. What puts an iPad into the
recorded state is not known, and a connection can still fail, with its dialog,
from a state that reports as ready. Only status values seen on a real device are
recorded, and any other value is attempted as usual, so an iPad that reports
differently is never refused. The recorded values so far come from one iPad
model.

If this happens on your iPad, the output of `sidecarctl devices --verbose` at
that moment is worth reporting in an issue.

### `connect --connection wired` exits 8

No iPad is attached by USB as far as the Mac can tell. Check the cable.

## Building

Needs Apple's command line tools (`xcode-select --install`).

```sh
xcrun swift build -c release
```

The binary is `.build/release/sidecarctl`.

### Tests

The unit tests cover argument parsing, device matching, the JSON output, and
which connections are tried in what order. With Xcode selected (`xcode-select -p`
names Xcode.app):

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

### Releases

`scripts/release.sh` builds, signs, and notarizes a zip in `dist/`. It needs a
Developer ID Application certificate and stored notarization credentials, and
its header says how to supply both.

## License

MIT. See [LICENSE](LICENSE).
