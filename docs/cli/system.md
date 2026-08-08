# `ed system`

`ed system` reports on the Mac you are typing on: a live CPU, memory, load and
network sample, and the volumes that are mounted. It reads the machine directly
through `sysctl`, the Mach host statistics, `/bin/ps` and `pmset`, so nothing
here talks to the Edith app and nothing here needs it running. Reach for it when
you want the numbers the app's This Mac view shows without opening a window, or
when you want them on stdout as JSON.

It is the local half of a pair. `ed machines metrics <machine>` is the same
report for a machine over SSH, in the same shape, so a script can treat both the
same way.

## At a glance

| Command | What it does |
| --- | --- |
| `ed system stats` | Samples CPU, memory, load, uptime, network and optionally the top processes. Streams with `--follow`. Runs when you type `ed system` with no subcommand. |
| `ed system disks` | Lists the mounted volumes with their size, free space and use, plus battery, temperature and GPU fields in JSON. |

## Commands

### `ed system stats`

Takes one sample of this Mac and prints it, or keeps sampling with `--follow`.
It is the default subcommand, so `ed system` on its own runs it.

```
ed system stats [--json] [--follow] [--interval <seconds>] [--processes <n>]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the human lines. Long form only, there is no `-j`. |
| `--follow`, `-f` | flag | off | Keep sampling until interrupted. Also switches `--json` from one pretty document to one compact document per line. |
| `--interval` | seconds, greater than 0 | `2` | Seconds between samples when following. Ignored without `--follow`, and clamped up to a floor of `0.5`. |
| `--processes` | integer, 0 or more | `0` | Include this many top processes by CPU in each sample. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Without `--follow` the command prints one sample and exits. The first line is a
header carrying the host name, the OS string and the core count; the second is
the sample itself:

```
$ ed system stats
Studio MacBook Pro  macOS Version 26.5.2 (Build 25F84)  14 cores
cpu  53.3%   mem 73% of 25.8 GB   load 16.54 19.29 17.56   net down 36.6 KB/s up 9.1 KB/s
```

`--processes n` appends a table of the top `n` processes by CPU under the
sample, the same rows the app's Processes tab shows for this Mac:

```
$ ed system stats --processes 5
Studio MacBook Pro  macOS Version 26.5.2 (Build 25F84)  14 cores
cpu  45.3%   mem 72% of 25.8 GB   load 16.54 19.29 17.56   net down 26.0 KB/s up 4.9 KB/s
PID    USER           CPU    MEM  NAME
20520  pulkit         195.1  0.0  turbo
405    _windowserver  32.3   0.3  WindowServer
36852  pulkit         21.6   1.7  Browser Helper (Renderer)
25053  pulkit         20.8   2.0  2.1.226
54438  pulkit         19.6   7.7  com.apple.Virtualization.VirtualMachine
```

With `--follow` the header prints once and each later sample adds one line. The
process table, if you asked for one, is reprinted under every sample rather than
once:

```
$ ed system stats --follow --interval 0.5
Studio MacBook Pro  macOS Version 26.5.2 (Build 25F84)  14 cores
cpu  61.5%   mem 74% of 25.8 GB   load 17.81 19.27 17.67   net down 39.2 KB/s up 85.0 KB/s
cpu  60.9%   mem 74% of 25.8 GB   load 17.81 19.27 17.67   net down 43.8 KB/s up 24.8 KB/s
cpu  65.0%   mem 74% of 25.8 GB   load 17.81 19.27 17.67   net down 49.4 KB/s up 20.9 KB/s
```

#### `--json` shape

One object with a `host` half that never changes and a `sample` half that does.
This is a real document, trimmed to one process, one network interface and
three of the fourteen `corePercent` entries:

```json
{
  "host": {
    "arch": "arm64",
    "cores": 14,
    "cpuModel": "Apple M4 Pro",
    "host": "Studio MacBook Pro",
    "kernel": "25.5.0",
    "memTotalKB": 25165824,
    "os": "macOS Version 26.5.2 (Build 25F84)",
    "osID": "macos",
    "virtual": false
  },
  "sample": {
    "at": "2026-08-08T16:37:59Z",
    "cpu": {
      "corePercent": [
        46.42857142857143,
        39.285714285714285,
        29.09090909090909
      ],
      "stealPercent": 0,
      "totalPercent": 52.78934221482098
    },
    "disk": {
      "devices": [],
      "readBps": 0,
      "writeBps": 0
    },
    "intervalSeconds": 0.5604119300842285,
    "load": [
      15.4755859375,
      18.97265625,
      17.46337890625
    ],
    "memory": {
      "availableKB": 6707072,
      "buffCacheKB": 5027472,
      "swapTotalKB": 5242880,
      "swapUsedKB": 3656192,
      "totalKB": 25165824,
      "usedKB": 18458752,
      "usedPercent": 73.34849039713541
    },
    "network": {
      "interfaces": [
        {
          "name": "en0",
          "rxBps": 58471.274862180486,
          "txBps": 436707.33412691054,
          "virtual": false
        }
      ],
      "rxBps": 58471.274862180486,
      "txBps": 436707.33412691054
    },
    "processes": [
      {
        "command": "/opt/homebrew/bin/turbo",
        "cpuPercent": 196.5,
        "memPercent": 0,
        "name": "turbo",
        "pid": 20520,
        "rssKB": 7312,
        "user": "pulkit"
      }
    ],
    "tasks": {
      "runnable": 0,
      "total": 566
    },
    "uptimeSeconds": 97895.422400625
  }
}
```

What the fields mean:

- `host.os` is built as the word `macOS` followed by the version string macOS
  itself reports, which is why it reads `macOS Version 26.5.2 (Build 25F84)`.
  `host.osID` is always `macos` here, and `host.virtual` is always `false`.
- `host.host` is the computer's Sharing name, falling back to `kern.hostname`.
  `host.kernel` is `kern.osrelease`, `host.arch` is `hw.machine`, and
  `host.cpuModel` is `machdep.cpu.brand_string`.
- `sample.at` is the sample time as `2026-08-08T16:37:59Z`, and
  `sample.intervalSeconds` is how long the window behind this sample actually
  was, which is close to but not exactly `--interval`.
- `cpu.totalPercent` is 0 to 100 across the whole machine, and `cpu.corePercent`
  has one entry per logical core in core order.
- Every `*KB` number is kilobytes and every `*Bps` number is bytes per second.
  `memory.usedPercent` is `usedKB` over `totalKB`.
- `load` is the one, five and fifteen minute load averages, in that order.
- `processes` is present even when it is empty, so the key never disappears
  between runs.

#### Examples

```
ed system stats
ed system stats --json
ed system stats --processes 10
ed system stats --follow --interval 5 --json | jq -c '{at: .sample.at, cpu: .sample.cpu.totalPercent}'
```

#### Behaviour notes

Nothing is mutated and nothing is written: the command samples and prints.
Neither the Edith app nor the menu bar helper has to be running, and no macOS
permission is involved, so this never exits 4.

The first sample costs about half a second. `ed` takes a throwaway sample,
sleeps 500 ms, then takes the one it prints, because CPU and network figures are
deltas between two readings and the first reading has nothing to compare
against. That is also why `intervalSeconds` on the first line of a `--follow`
run reads around `0.56` rather than your `--interval`.

`--interval` is validated as greater than zero and finite, so `--interval 0`,
a negative value and `--interval nan` all exit 2 before any sampling happens.
`--processes` is validated as zero or more and exits 2 when negative, though
you have to write `--processes=-1` to get there: `--processes -1` is read as a
missing value by the parser and exits 2 for that reason instead.

```
$ ed system stats --interval 0
error: --interval must be greater than zero

$ ed system stats --processes=-1
error: --processes cannot be negative
hint: pass 0 or more
```

Interrupting a `--follow` run with Ctrl-C is the normal way to stop it. There is
no sample count option and no timeout.

### `ed system disks`

Lists the mounted volumes with their size, free space and how full they are.

```
ed system disks [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

The table has one row per volume, and prints its headings even when there are no
rows:

```
$ ed system disks
VOLUME        MOUNT  SIZE    FREE    USED
Macintosh HD  /      494 GB  170 GB  66%
```

#### `--json` shape

Four keys, always all four:

```json
{
  "battery": {
    "percent": 99,
    "status": "Finishing Charge"
  },
  "filesystems": [
    {
      "availableKB": 166164022,
      "filesystem": "Macintosh HD",
      "mount": "/",
      "totalKB": 482797652,
      "usedKB": 316633630,
      "usedPercent": 65.58309235522131
    }
  ],
  "gpu": null,
  "temperatures": []
}
```

`filesystem` is the volume's name, not its device node, and `mount` is where it
is mounted. `usedKB` is `totalKB` minus `availableKB`, and `usedPercent` is
`usedKB` over `totalKB`.

`battery` is read from `pmset -g batt` and carries `percent` and a capitalised
`status` such as `Charging`, `Discharging` or `Finishing Charge`. It is `null`
on a Mac with no battery, and `null` rather than missing, so the key is always
there.

`temperatures` and `gpu` are part of the shared report shape the Linux collector
fills in for a remote machine. The local sampler collects neither, so on this
Mac `temperatures` is always `[]` and `gpu` is always `null`. No `ed` command
prints a remote machine's values either: `ed machines metrics` keeps the sample
half and drops the volume, battery, temperature and GPU record, which reaches
the app's Machines window instead. The keys, when a machine does report them,
are:

```json
{
  "gpu": {
    "memTotalMB": 8188,
    "memUsedMB": 1204,
    "name": "NVIDIA GeForce RTX 4060",
    "temperature": 47,
    "utilPercent": 12
  },
  "temperatures": [
    {
      "celsius": 43.5,
      "label": "Package id 0"
    }
  ]
}
```

#### Examples

```
ed system disks
ed system disks --json
ed system disks --json | jq -r '.filesystems[] | "\(.mount) \(.usedPercent | floor)%"'
```

#### Behaviour notes

Read only, instant, and needs neither the app nor a permission. The one
subprocess it runs is `pmset`, for the battery line, and a `pmset` that fails to
run is reported as `battery: null` rather than as an error.

Only volumes macOS marks browsable and not hidden, and that report a capacity
above zero, are listed, so the Preboot, Recovery and VM volumes that `mount` and
`df` show do not appear here.

Free space is the space macOS calls available for important usage, which counts
purgeable caches it would evict for you. That is the figure Finder shows, and it
is usually larger than what `df` prints for the same volume.

This is one of the few commands that does not run inside the CLI's failure
wrapper, which changes nothing you can observe: the top level reports and codes
a failure identically.

## Exit codes

| Code | When |
| --- | --- |
| 0 | The sample or the volume list was printed. `--help` and `--version` also exit 0. |
| 2 | `--interval` was zero, negative or not finite; `--processes` was negative; or the command line was wrong in the ordinary way, an unknown flag, a missing value, or a value that is not a number. |

Neither command looks anything up by name and neither talks to the app, so 3 and
4 cannot happen here. Code 1 is the catch-all for an unexpected error escaping
`ed system stats`, and nothing on the local sampling path throws one.

## Notes and gotchas

- `ed system` with no subcommand is `ed system stats`. `stats` is declared as
  the group's default subcommand, so the two are the same invocation.
- Sizes are formatted with decimal units. `KB` is 1000 bytes, `MB` is 1000 KB,
  and so on, which is why a volume of 482797652 KB prints as `494 GB` rather
  than `460 GB` and 25165824 KB of memory prints as `25.8 GB`. The JSON is raw
  kilobytes, so do your own maths there if you want binary units.
- At most 30 processes exist to be reported. The sampler keeps the top 30 by
  CPU, so `--processes 50` gives you 30 rows and no warning.
- `cpuPercent` in the process rows comes from `ps` and is summed across cores,
  so a busy process reads above 100. `cpu.totalPercent` for the machine is
  capped at 100 across all cores. The two are not on the same scale.
- The process list is `/bin/ps -axo pid=,user=,%cpu=,%mem=,rss=,comm=` sorted by
  CPU descending, and `name` is the last path component of `command`.
- Network counters skip `lo0` entirely, and an interface that moved no bytes
  during the window is left out of `interfaces` rather than listed at zero. The
  `rxBps` and `txBps` totals exclude interfaces judged virtual, which is
  anything named `utun*`, `awdl*`, `llw*`, `bridge*`, `ap*`, `gif*`, `stf*` or
  `anpi*`; those interfaces still appear in the list, with `virtual: true`.
- `disk.readBps`, `disk.writeBps` and `disk.devices`, along with
  `cpu.stealPercent` and `tasks.runnable`, are part of the shared sample shape
  and are always zero or empty for this Mac. They are filled in by the collector
  `ed machines metrics` runs on a Linux machine.
- `tasks.total` is the number of processes `ps` returned, so it counts every
  process on the machine and not just the ones `--processes` shows.
- `--json --follow` writes one compact document per line, forever, and repeats
  the whole `host` object on every line. That is deliberate: each line stands
  alone, so `jq -c`, `head` and a pipe into another process all work without
  buffering a document that never ends. Without `--follow` you get a single
  pretty-printed document instead.
- Object keys are sorted, in both the pretty and the compact form, so two runs
  diff cleanly.
- `stats` is the same `LocalMachineSampler` the app drives for its This Mac
  session, so the CLI and the window cannot disagree about a number. The window
  samples every two seconds and refreshes its volume and battery half on every
  fifteenth tick, about every thirty seconds; `ed system disks` reads it fresh
  on every call.
- The `systemStats` extension, the CPU and memory readout in the menu bar, is
  unrelated to these commands. `ed system` never consults it, and both commands
  work with every extension turned off.

## Where to go next

- [`ed machines`](./machines.md) for the same sample taken on another machine
  over SSH, including the disk, steal and task fields this page reports as zero.
- [`ed cleaner`](./cleaner.md) for acting on what `ed system disks` tells you
  about free space.
- [`ed extensions`](./extensions.md) for the menu bar CPU and memory readout.
- [The `ed` command line](./README.md) for the rest of the reference.
