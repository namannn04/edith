import os

/// App-wide unified logging. `.notice`/`.error` persist to disk, so past runs
/// can be pulled without a live stream:
///
///   log show --last 1d --predicate 'subsystem == "com.pulkit.edith"' --info
///
/// Live tail while reproducing:
///
///   log stream --predicate 'subsystem == "com.pulkit.edith"'
///
/// Never log the OAuth token; percentages, HTTP codes, and states are fine.
enum Log {
    static let usage = Logger(subsystem: "com.pulkit.edith", category: "usage")
    static let lifecycle = Logger(subsystem: "com.pulkit.edith", category: "lifecycle")
}
