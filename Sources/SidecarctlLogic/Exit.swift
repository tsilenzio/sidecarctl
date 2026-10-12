// The exit codes, which callers branch on, so a case keeps its number once released.

public enum Exit: Int32 {
    case ok = 0, usage, noDevices, noSuchDevice, sidecarError, unavailable, ambiguous, alreadyRunning, noTransport, notReady
}
