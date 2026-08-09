# `ed machines docker start`

Starts a stopped container.

```
ed machines docker start [--json] <machine> <container>...
```

## Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<container>...` | one or more container names or ids | at least one required | Which containers to start. Docker is given all of them in one call. |

## Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Human output is one line, `start <container>`.

## `--json` shape

```json
{
  "action": "start",
  "containers": [
    "open-webui"
  ],
  "machine": "Asus TUF 7"
}
```

`machine` is the machine's display name as Edith stores it, not what you typed.
`containers` echoes back exactly what you typed, in the order you typed it, so
passing a short id gives you a short id here. Naming no container at all exits 1
with `name at least one container`, before the machine is dialled.

## Examples

```
ed machines tuf docker start open-webui
ed machines tuf docker start b556d7fef23e --json
ed machines tuf docker start api postgres redis
```

## Behaviour notes

Runs `docker start <container>...` with a 120 second ceiling, one call however
many containers are named. A docker that refuses exits 1, with docker's own
stderr as the hint:

```
$ ed machines tuf docker start nosuch-container
error: docker start failed on Asus TUF 7
hint: Error response from daemon: No such container: nosuch-container
failed to start containers: nosuch-container
```

This is the Docker window's start button, running the same command, and naming
several containers is what the play button on a group header does.

## Where to go next

- [`ed machines docker`](./README.md), the rest of this group
- [All `ed` commands](../README.md)
