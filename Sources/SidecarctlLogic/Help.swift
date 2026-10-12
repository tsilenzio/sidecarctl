// Bumped by hand for a release, to match its tag without the leading v
public let version = "0.1.0"

public let commands = ["devices", "connect", "disconnect", "status", "boost"]

// The help for one command, or for the tool as a whole when the topic is not one
public func help(for topic: String?) -> String {
    switch topic {
    case "devices": return devicesHelp
    case "connect": return connectHelp
    case "disconnect": return disconnectHelp
    case "status": return statusHelp
    case "boost": return boostHelp
    default: return overview
    }
}

let overview = """
    usage: sidecarctl <command>

    sidecarctl starts and ends Sidecar, which turns an iPad into a second
    display for this Mac. It picks the cable or Wi-Fi for you, or as you tell
    it.

    It can also route the session through a virtual display, which made
    Sidecar more responsive on the iPad Pro it was tested with. Results vary.

    commands:
      devices       list the iPads this Mac can reach
      connect       start a Sidecar session, through a virtual display with --boost
      disconnect    end a Sidecar session
      status        show the live session and whether a boost is running
      boost         route a session that is already up through a virtual display
      help          show this text, or `help <command>` for one command
      --version     print sidecarctl's own version

    Add --help to any command to read what it does and the options it takes.

    To connect to the one iPad around:
      sidecarctl connect
    """

let devicesHelp = """
    usage: sidecarctl devices [--verbose | --json]

    Lists the iPads this Mac can reach for Sidecar, one to a line: the iPad's
    UUID, a tab, and its name.

    Either the UUID or the name tells `connect` and `disconnect` which iPad you
    mean. The name is easier to type. The UUID suits a script, since it keeps
    the iPad's name out of the script.

    An iPad shows here when it is signed in to the same Apple Account as this
    Mac and is nearby or attached by cable. Being listed does not promise it
    will connect, since an iPad that has sat unused can be listed and still
    refuse.

      --verbose   add a tab and the status value Sidecar reports for the iPad,
                  which is the value to send along when reporting a problem
      --json      print one line of JSON, for a program to read

    Exits 2 when no iPad is reachable.
    """

let connectHelp = """
    usage: sidecarctl connect [<device>] [--connection <how>] [--boost [--hz <rate>] [--retina]]
                              [--retries <count>] [--framerate <fps>] [--low-latency]
                              [--ignore-not-ready]

    Starts a Sidecar session, so the iPad becomes a second display.

    <device> is an iPad's name or its UUID, as `sidecarctl devices` lists them.
    Leave it out when only one iPad is reachable.

    If a session to that iPad is already running the way you asked, it is kept
    and this exits 0, so it is safe to run again. If one is running some other
    way, over Wi-Fi when you asked for the cable for example, it is ended and
    started afresh.

      --connection <how>   how the session is carried, one of:
                             prefer-wired   the cable when an iPad is plugged
                                            in, and Wi-Fi otherwise. This is
                                            what you get with no --connection.
                             wired          the cable or nothing
                             wireless       Wi-Fi, even with the cable in
                             system         whichever Sidecar itself picks

      --boost              once connected, route the session through a virtual
                           display, which may make the iPad more responsive.
                           `sidecarctl help boost` says what to expect. The
                           command then keeps running for as long as the
                           session lasts. Stop it with Ctrl-C or with
                           `sidecarctl boost --stop`, and the session ends too.
      --hz <rate>          with --boost, the rate the virtual display is set
                           to, 120 unless given
      --retina             with --boost, twice the pixels each way for sharper
                           text, at four times the work for the Mac

      --retries <count>    try again this many times, 3 seconds apart, when the
                           iPad is not ready or the connection fails. None
                           unless you ask, because macOS shows a dialog for
                           every attempt Sidecar refuses.
      --ignore-not-ready   try even when the iPad reports it is not ready

      --framerate <fps>    the rate Sidecar streams at, 60 unless given. This
                           is Sidecar's own setting and is separate from --boost.
      --low-latency        turn on Sidecar's low latency mode

    Exits 8 for `--connection wired` with no iPad plugged in, 9 when the iPad
    reports it is not ready, and 4 when Sidecar refuses the connection.
    """

let disconnectHelp = """
    usage: sidecarctl disconnect [<device>]

    Ends the Sidecar session to an iPad.

    <device> is an iPad's name or its UUID, as `sidecarctl devices` lists them.
    Leave it out when only one iPad is reachable.

    Exits 0 when there was no session to end, so it is safe to run whether or
    not one is up. A boost running on the session stops with it.
    """

let statusHelp = """
    usage: sidecarctl status [--json]

    Shows what is running: each live Sidecar session with its iPad, whether it
    is wired or wireless, and its framerate, then whether a boost is running.

    It answers even with no iPad reachable, and always exits 0 when it could
    ask. Read the output to learn the state.

      --json   print one line of JSON, for a program to read. `sessions` lists
               the live sessions, and `boost` is the running boost's process
               ID, left out when there is none.
    """

let boostHelp = """
    usage: sidecarctl boost [--hz <rate>] [--retina]
           sidecarctl boost --stop

    Routes a Sidecar session that is already up through a virtual display.
    It adds a second, virtual display set to a higher refresh rate than
    Sidecar's own and has Sidecar's display copy it, so the Mac draws at the
    virtual display's rate and Sidecar sends on what it drew.

    This made Sidecar more responsive on the iPad Pro it was tested with. It
    promises no particular rate. Results depend on the iPad and the Mac, and
    may be no different from plain Sidecar.

    Use this for a session started some other way, from Control Center for
    example. To start the session and boost it in one go, use
    `sidecarctl connect --boost`.

    It keeps running until the session ends or you stop it, and stopping it
    here leaves the session up as plain Sidecar. While it runs, macOS lists one
    more display, named after the iPad.

      --hz <rate>   the rate the virtual display is set to, 120 unless given.
                    This is what the Mac draws at, and what reaches the iPad
                    may be lower.
      --retina      twice the pixels each way for sharper text, at four times
                    the work for the Mac
      --stop        end the boost that is running

    Exits 2 when no Sidecar display appears, and 7 when a boost is already
    running.
    """
