# `ed machines docker`

`ed machines docker` is the parsed view of docker on another machine. Every verb
here opens the shared SSH connection, runs one real docker command with
`--format '{{json .}}'` where docker offers it, and turns the answer into stable
fields, so a script never has to scrape a column layout. It is the same set of
operations the app's Docker window performs, running the same commands.

Nothing is installed on the far side and nothing is proxied through the Edith
app: this is `/usr/bin/ssh` over the ControlMaster socket the app shares, so
these commands work with Edith closed. What they need is docker on the machine
and a user who can reach its socket.

There are two ways into docker on a machine, and the difference matters.
`ed machines <machine> docker ps` is this page: parsed, `--json`, stable keys.
`ed <machine> docker ps` is the raw shorthand, which sends the line to the
remote shell verbatim and gives you docker's own output and exit code. Reach for
the raw form for anything this page does not cover, `ed tuf docker buildx ls`
being the usual example.

## At a glance

| Command | What it does |
| --- | --- |
| `ed machines docker ps` | Lists containers merged with live CPU and memory. Runs when you name no subcommand. |
| `ed machines docker images` | Lists images with their size and whether they are dangling. |
| `ed machines docker volumes` | Lists volumes with their driver and mountpoint. |
| `ed machines docker networks` | Lists networks with their driver and scope. |
| `ed machines docker df` | Disk usage by object type, with what is reclaimable. |
| `ed machines docker logs` | Streams one container's logs, with timestamps. |
| `ed machines docker inspect` | Prints docker's own `inspect` JSON, untouched. |
| `ed machines docker start` | Starts one or more containers. |
| `ed machines docker stop` | Stops one or more containers, with a 10 second grace period. |
| `ed machines docker restart` | Restarts one or more containers, with a 10 second grace period. |
| `ed machines docker rm` | Removes one or more containers, killing them first. Destructive, and there is no `--yes`. |
| `ed machines docker pause` | Freezes the processes of one or more containers. |
| `ed machines docker unpause` | Lets one or more frozen containers run again. |
| `ed machines docker rmi` | Removes an image. Destructive. Aliased `remove-image`. |
| `ed machines docker volume-rm` | Removes a volume and the data in it. Destructive, needs `--yes`. |
| `ed machines docker prune` | Reclaims space from unused objects. Destructive, needs `--yes`. |
| `ed machines docker compose ls` | Lists compose projects. Runs when you name no compose subcommand. Aliased `list`. |
| `ed machines docker compose up` | Brings a project up in the background. |
| `ed machines docker compose down` | Takes a project down, removing its containers and networks. Destructive. |
| `ed machines docker compose restart` | Restarts a project. |
| `ed machines docker compose pull` | Pulls the images a project uses. |
| `ed machines docker compose logs` | Streams the whole project's logs. |

## What destroys data, and what guards it

Five verbs remove something, and only `volume-rm` and `prune` ask first. Read
this table before you script any of them.

| Command | What disappears | Guard |
| --- | --- | --- |
| `ed machines docker rm` | The container, killed first with `docker rm -f`. Anything written inside it and not in a volume goes with it. | none |
| `ed machines docker rmi` | The image. With `--force`, even while a container still refers to it. | none |
| `ed machines docker volume-rm` | The volume and every byte in it. This is where databases live. | `--yes` |
| `ed machines docker prune volumes` | Every volume no container currently uses, and their contents. | `--yes` |
| `ed machines docker prune images` | Every image no container uses, not only the dangling ones: the command is `docker image prune -af`. | `--yes` |
| `ed machines docker compose down` | The project's containers and its network. Named volumes survive, because `-v` is never passed. | none |

`prune system`, `prune networks` and `prune builder` remove stopped containers,
unused networks, dangling images and build cache. `docker system prune -f` is
what runs for `system`, without `--volumes`, so volume data is never caught by
it. `prune` and `volume-rm` without `--yes` report what they would do, change
nothing, and exit 0.

## Commands

### `ed machines docker ps`

Lists containers, merging `docker ps -a` with a one-shot `docker stats` so each
row carries live CPU and memory next to its state and ports. It is the group's
default subcommand, so `ed machines docker <machine>` runs it.

```
ed machines docker ps [--json] [--all] <machine>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. Long form only, there is no `-j`. |
| `--all`, `-a` | flag | off | Include containers that are not running. Without it only `running` and `restarting` containers are listed. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

The table prints its headings even when nothing matches:

```
$ ed machines tuf docker ps
ID  NAME  IMAGE  STATE  CPU  PORTS

$ ed machines tuf docker ps --all
ID            NAME                          IMAGE                               STATE   CPU  PORTS
b556d7fef23e  lobe-chat                     lobehub/lobe-chat:latest            exited  -
f8968a8b81e5  open-webui                    ghcr.io/open-webui/open-webui:main  exited  -
47e37ace9821  noveum-local-db-postgres-1    postgres:17-alpine                  exited  -
efe6aaaae124  noveum-local-db-clickhouse-1  clickhouse/clickhouse-server:24.12  exited  -
5477a5a28510  noveum-local-db-redis-1       redis/redis-stack:latest            exited  -
```

With the same containers running, the `CPU` and `PORTS` columns fill in and the
stopped rows are gone:

```
$ ed machines tuf docker ps
ID            NAME                          IMAGE                               STATE    CPU    PORTS
b556d7fef23e  lobe-chat                     lobehub/lobe-chat:latest            running  0.0%
f8968a8b81e5  open-webui                    ghcr.io/open-webui/open-webui:main  running  0.3%   3000 → 8080/tcp
47e37ace9821  noveum-local-db-postgres-1    postgres:17-alpine                  running  2.7%   5433 → 5432/tcp
```

`CPU` reads `-` when `docker stats` had nothing to say about that container,
which is every stopped container and, briefly, one that has just started.

#### `--json` shape

A top-level array, one object per container, in the order docker listed them.
This is a real document trimmed to one entry:

```json
[
  {
    "command": "\"docker-entrypoint.sh postgres\"",
    "composeProject": "noveum-local-db",
    "composeService": "postgres",
    "cpuPercent": null,
    "createdAt": "2026-08-05 22:28:30 +0530 IST",
    "health": "none",
    "id": "47e37ace98211bfcf5d14f4f6e80e4d76b09c30914cb8e8ecf7e14cc029f237e",
    "image": "postgres:17-alpine",
    "memLimitBytes": null,
    "memUsedBytes": null,
    "name": "noveum-local-db-postgres-1",
    "names": [
      "noveum-local-db-postgres-1"
    ],
    "ports": [],
    "shortID": "47e37ace9821",
    "state": "exited",
    "status": "Exited (0) 2 hours ago"
  }
]
```

What the fields mean:

- `id` is the full container id, because `docker ps` runs with `--no-trunc`.
  `shortID` is its first twelve characters, which is what the table prints and
  what every other verb here accepts.
- `name` is the first of `names`; `names` holds all of them, since a container
  can carry several. A container with no name at all falls back to `shortID`.
- `state` is one of `created`, `running`, `paused`, `restarting`, `exited`,
  `dead`, `removing`, or `unknown` when docker reports something newer than
  that list. `status` is docker's own sentence, such as `Exited (0) 2 hours
  ago`.
- `health` is `none`, `starting`, `healthy` or `unhealthy`. It comes from
  docker's `HealthStatus` field, falling back to reading `(healthy)`,
  `(unhealthy)` or `health: starting` out of `status`. A container with no
  health check reports `none`.
- `ports` is an array of strings, each rendered as `5433 → 5432/tcp` with a
  literal arrow, or as `5432/tcp` alone when the port is exposed but not
  published. Do not expect `->`. Duplicate IPv4 and IPv6 mappings are collapsed
  into one entry, and the list is sorted by host port, with unpublished ports
  last.
- `composeProject` and `composeService` come from the
  `com.docker.compose.project` and `com.docker.compose.service` labels, and are
  `null` on a container compose did not create.
- `createdAt` is docker's own string, `2026-08-05 22:28:30 +0530 IST`. It is not
  ISO 8601, unlike dates elsewhere in `ed --json`.
- `command` is docker's quoted form, so the value usually contains its own
  quotation marks.
- `cpuPercent`, `memUsedBytes` and `memLimitBytes` come from `docker stats
  --no-stream` and are `null` for anything not running. `cpuPercent` is docker's
  own figure, summed across cores, so a busy container reads above 100.

#### Examples

```
ed machines tuf docker ps
ed machines tuf docker ps --all --json
ed machines tuf docker ps --json | jq -r '.[] | select(.health == "unhealthy") | .name'
ed machines tuf docker ps --json | jq -r '.[] | "\(.name) \(.ports | join(","))"'
```

#### Behaviour notes

Read only. The remote command is `docker ps -a --no-trunc --format '{{json .}}'`
followed by `docker stats --no-stream`, sent as one line with a separator
between them, with a 45 second ceiling. `docker stats` has its stderr thrown
away, so its noise never lands in the parse, and a container it says nothing
about is still listed with its stats null. Its exit status is the status of the
whole line, though, so a `docker stats` that fails outright takes the container
list down with it and exits 1.

`--all` is a client-side filter, not `docker ps` without `-a`: the machine
always returns every container and `ed` drops the ones that are neither
`running` nor `restarting`. The consequence worth remembering is that a paused
container does not appear without `--all`.

### `ed machines docker images`

Lists the images on the machine with their size.

```
ed machines docker images [--json] <machine>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines tuf docker images
ID            IMAGE                                                SIZE
e97bf9531916  ghcr.io/open-webui/open-webui:main                   5.1 GB
de3a4eab8fdf  postgres:16-alpine                                   294 MB
93aa428db0ae  postgres:17-alpine                                   297 MB
7ef7a41df1e0  lobehub/lobe-chat:latest                             617 MB
9eafe528d67a  redis/redis-stack:latest                             895 MB
af182398db7c  docker.elastic.co/kibana/kibana:9.0.0                1.2 GB
6cec5391a4c7  docker.elastic.co/elasticsearch/elasticsearch:9.0.0  1.4 GB
```

#### `--json` shape

A top-level array, one object per image:

```json
[
  {
    "createdSince": "12 days ago",
    "dangling": false,
    "id": "sha256:e97bf95319168ab7fdfc5bd1e869f6a1cf6349bdf6d3e8fe16c733d2ca473491",
    "repository": "ghcr.io/open-webui/open-webui",
    "shortID": "e97bf9531916",
    "sizeBytes": 5090000000,
    "tag": "main"
  },
  {
    "createdSince": "4 weeks ago",
    "dangling": false,
    "id": "sha256:de3a4eab8fdfa507ea92aac488b916b08089e515db49b055fe71dfa271ba3a28",
    "repository": "postgres",
    "shortID": "de3a4eab8fdf",
    "sizeBytes": 294000000,
    "tag": "16-alpine"
  }
]
```

- `id` keeps docker's `sha256:` prefix; `shortID` strips it and keeps twelve
  characters, which is what the table shows and what `rmi` takes.
- `dangling` is true when either `repository` or `tag` is `<none>`, and the
  table prints such a row as `<none>:<none>`.
- `sizeBytes` is docker's human size parsed back into bytes. Docker prints
  decimal units, so `5.09GB` becomes `5090000000` rather than a byte-exact
  figure, and the table then re-renders it as `5.1 GB`.
- `createdSince` is docker's relative phrase, not a date.

#### Examples

```
ed machines tuf docker images
ed machines tuf docker images --json | jq -r '.[] | select(.dangling) | .shortID'
ed machines tuf docker images --json | jq 'map(.sizeBytes) | add'
```

#### Behaviour notes

Read only, 45 second ceiling. The remote command is
`docker images --no-trunc --format '{{json .}}'`, with no `-a`, so intermediate
build layers are not listed. Dangling images are, and `prune images` takes them
along with every other image no container uses.

### `ed machines docker volumes`

Lists the volumes on the machine.

```
ed machines docker volumes [--json] <machine>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines tuf docker volumes
NAME                                                              DRIVER  MOUNTPOINT
7a438a4d027cfca045e0fcb4caa787c1e26e70ef7839917dce8b768da5a4fc38  local   /var/lib/docker/volumes/7a438a4d027cfca045e0fcb4caa787c1e26e70ef7839917dce8b768da5a4fc38/_data
crowdvolt_postgres_data                                           local   /var/lib/docker/volumes/crowdvolt_postgres_data/_data
noveum-local-db_postgres_data                                     local   /var/lib/docker/volumes/noveum-local-db_postgres_data/_data
open-webui                                                        local   /var/lib/docker/volumes/open-webui/_data
pg_data                                                           local   /var/lib/docker/volumes/pg_data/_data
```

#### `--json` shape

```json
[
  {
    "containers": null,
    "driver": "local",
    "inUse": false,
    "mountpoint": "/var/lib/docker/volumes/pg_data/_data",
    "name": "pg_data",
    "sizeBytes": null
  }
]
```

`sizeBytes`, `containers` and `inUse` are part of the shape the app's Docker
window fills in, and the CLI never fills them: it runs `docker volume ls` only,
never `docker system df -v`, so `sizeBytes` and `containers` are always `null`
and `inUse` is always `false`. The keys are present rather than dropped, so the
document shape does not change between runs. For real volume sizes use
`ed machines docker df`, which reports the total and reclaimable figures for
`Local Volumes`.

#### Examples

```
ed machines tuf docker volumes
ed machines tuf docker volumes --json | jq -r '.[].name'
ed machines tuf docker volumes --json | jq -r '.[] | select(.name | startswith("noveum")) | .mountpoint'
```

#### Behaviour notes

Read only, 45 second ceiling, `docker volume ls --format '{{json .}}'`. An
anonymous volume is listed under its 64 character hash, which is exactly the
name `volume-rm` wants.

### `ed machines docker networks`

Lists the docker networks on the machine.

```
ed machines docker networks [--json] <machine>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines tuf docker networks
NAME                     DRIVER  SCOPE
bridge                   bridge  local
host                     host    local
none                     null    local
noveum-local-db_default  bridge  local
```

#### `--json` shape

```json
[
  {
    "driver": "bridge",
    "id": "5b5aedee9cc4",
    "name": "bridge",
    "scope": "local"
  },
  {
    "driver": "bridge",
    "id": "a3f0be1c77d2",
    "name": "noveum-local-db_default",
    "scope": "local"
  }
]
```

`id` is the truncated twelve character id docker prints for networks, not the
full one: unlike `ps` and `images`, this command does not pass `--no-trunc`.

#### Examples

```
ed machines tuf docker networks
ed machines tuf docker networks --json | jq -r '.[] | select(.driver == "bridge") | .name'
```

#### Behaviour notes

Read only, 30 second ceiling, `docker network ls --format '{{json .}}'`. The
three built-in networks, `bridge`, `host` and `none`, are always listed and are
never touched by `prune networks`.

### `ed machines docker df`

Reports docker's disk usage by object type, and how much of it is reclaimable.

```
ed machines docker df [--json] <machine>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines tuf docker df
TYPE           TOTAL  ACTIVE  SIZE     RECLAIMABLE
Images         12     5       11.3 GB  3.6 GB
Containers     5      0       462 MB   462 MB
Local Volumes  10     4       11.7 GB  273 MB
Build Cache    0      0       0 B      0 B
```

#### `--json` shape

```json
[
  {
    "active": 5,
    "reclaimableBytes": 3585000000,
    "sizeBytes": 11310000000,
    "total": 12,
    "type": "Images"
  },
  {
    "active": 4,
    "reclaimableBytes": 272700000,
    "sizeBytes": 11730000000,
    "total": 10,
    "type": "Local Volumes"
  }
]
```

- `type` is docker's own label: `Images`, `Containers`, `Local Volumes` and
  `Build Cache`, capitalised and spaced exactly like that.
- `total` is docker's `TotalCount` and `active` is how many of them are in use.
- `sizeBytes` and `reclaimableBytes` are parsed from docker's decimal strings.
  Docker prints reclaimable as `3.585GB (31%)`; the percentage is dropped and
  only the size is kept.

This is the report to read before pruning. `reclaimableBytes` for `Images` is
what `prune images` would free, and the `Local Volumes` row is what
`prune volumes` would free, which is data rather than cache.

#### Examples

```
ed machines tuf docker df
ed machines tuf docker df --json | jq -r '.[] | "\(.type) \(.reclaimableBytes)"'
ed machines tuf docker df --json | jq 'map(.reclaimableBytes) | add'
```

#### Behaviour notes

Read only, 45 second ceiling, `docker system df --format '{{json .}}'`. On a
busy daemon this is the slowest of the read commands, because docker walks the
image and volume trees to answer it.

### `ed machines docker logs`

Streams one container's logs to your terminal.

```
ed machines docker logs [--tail <n>] [--follow] <machine> <container>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |
| `<container>` | container name or id, full or short | required | Which container's logs to read. Passed to docker as given. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--tail` | integer, 0 or more | `200` | How many trailing lines to show. `0` shows none, which is what you want with `--follow`. |
| `--follow`, `-f` | flag | off | Keep streaming until interrupted. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

There is no `--json` here, and no `--since` or `--until`: this is a passthrough
of docker's own output.

```
$ ed machines tuf docker logs lobe-chat --tail 3
2026-08-08T07:38:18.342112977Z Warning: Cannot polyfill `DOMMatrix`, rendering may be broken.
2026-08-08T07:38:18.342116199Z Warning: Cannot polyfill `ImageData`, rendering may be broken.
2026-08-08T07:38:18.342119077Z Warning: Cannot polyfill `Path2D`, rendering may be broken.
```

#### Examples

```
ed machines tuf docker logs lobe-chat
ed machines tuf docker logs tuf-api --tail 50
ed machines tuf docker logs open-webui --tail 0 --follow
```

#### Behaviour notes

The remote command is
`docker logs --timestamps --tail <n> [--follow] <container>`. Timestamps are
always on and cannot be turned off, which is the one way this differs from
typing `docker logs` yourself.

Output is streamed line by line as it arrives, with the container's stdout going
to your stdout and its stderr going to your stderr, so redirecting one does not
swallow the other. There is no timeout: `--follow` runs until you interrupt it
or the container stops.

This is one of the two verbs on this page that propagate the remote exit code
instead of mapping it into the 0 to 4 table. A container that does not exist is
docker's error, on stderr, with docker's status, usually 1. `--tail` is
validated before anything is sent: a negative value exits 2, though you have to
write `--tail=-1` to reach the check because `--tail -1` is read as a missing
value and exits 2 for that reason instead.

```
$ ed machines tuf docker logs open-webui --tail=-1
error: --tail cannot be negative
hint: pass 0 or more
```

### `ed machines docker inspect`

Prints docker's own `inspect` output for a container, untouched.

```
ed machines docker inspect <machine> <container>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |
| `<container>` | container name or id | required | What to inspect. Passed to `docker inspect` as given. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

This command has no `--json` flag, because all of its output already is JSON:
docker's array of one object, printed exactly as docker produced it, with
docker's own key names and key order.

```
$ ed machines tuf docker inspect lobe-chat | head -8
[
    {
        "Id": "b556d7fef23e992287fe837df535b4dcfbdf2aaa48f90ee9f96fdc994ed5d79d",
        "Created": "2026-08-06T22:20:40.507261889Z",
        "Path": "/bin/node",
        "Args": [
            "/app/startServer.js"
        ],
```

#### Examples

```
ed machines tuf docker inspect lobe-chat
ed machines tuf docker inspect lobe-chat | jq -r '.[0].State.Status'
ed machines tuf docker inspect lobe-chat | jq -r '.[0].Config.Env[]'
```

#### Behaviour notes

The remote command is `docker inspect <container> 2>/dev/null`, with a 30 second
ceiling. Because it is plain `docker inspect`, it answers for any docker object,
so an image name, a volume or a network works here too even though the argument
is called `container`.

The two failure paths are worth telling apart. When docker itself fails, which
is what a missing container does, the non-zero status is reported and the
command exits 1; docker's stderr was discarded by the `2>/dev/null`, so the hint
falls back to what landed on stdout, which for a missing object is `[]`:

```
$ ed machines tuf docker inspect nosuch-container
error: docker inspect nosuch-container 2>/dev/null exited 1 on Asus TUF 7
hint: []
```

When docker succeeds but prints nothing at all, `ed` reports
`no container named <container>` and exits 3.

### `ed machines docker start`

Starts a stopped container.

```
ed machines docker start [--json] <machine> <container>...
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<container>...` | one or more container names or ids | at least one required | Which containers to start. Docker is given all of them in one call. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Human output is one line, `start <container>`.

#### `--json` shape

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

#### Examples

```
ed machines tuf docker start open-webui
ed machines tuf docker start b556d7fef23e --json
ed machines tuf docker start api postgres redis
```

#### Behaviour notes

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

### `ed machines docker stop`

Stops a running container.

```
ed machines docker stop [--json] <machine> <container>...
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<container>...` | one or more container names or ids | at least one required | Which containers to stop. Docker is given all of them in one call. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "action": "stop",
  "containers": [
    "open-webui"
  ],
  "machine": "Asus TUF 7"
}
```

#### Examples

```
ed machines tuf docker stop open-webui
ed machines tuf docker stop open-webui --json
```

#### Behaviour notes

Runs `docker stop -t 10 <container>...`, so each container gets ten seconds to
exit on its own before docker kills it. The stop button on a group header in the
Docker window is this command with every running container in the group named. The whole call has a 120 second ceiling.
Stopping a container that is already stopped is docker's business and succeeds
quietly. Failure exits 1 with docker's stderr as the hint.

### `ed machines docker restart`

Restarts a container.

```
ed machines docker restart [--json] <machine> <container>...
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<container>...` | one or more container names or ids | at least one required | Which containers to restart. Docker is given all of them in one call. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "action": "restart",
  "containers": [
    "noveum-local-db-postgres-1"
  ],
  "machine": "Asus TUF 7"
}
```

#### Examples

```
ed machines tuf docker restart noveum-local-db-postgres-1
ed machines tuf docker restart open-webui --json
```

#### Behaviour notes

Runs `docker restart -t 10 <container>`, the same ten second grace period `stop`
uses, under the same 120 second ceiling. A container that takes longer than the
ceiling to come back leaves `ed` reporting a failure while docker carries on;
check with `ed machines docker ps` rather than assuming the restart was lost.

### `ed machines docker rm`

Removes a container, killing it first.

```
ed machines docker rm [--json] <machine> <container>...
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<container>...` | one or more container names or ids | at least one required | Which containers to remove. Docker is given all of them in one call. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "action": "rm",
  "containers": [
    "open-webui"
  ],
  "machine": "Asus TUF 7"
}
```

#### Examples

```
ed machines tuf docker rm open-webui
ed machines tuf docker rm b556d7fef23e --json
```

#### Behaviour notes

The remote command is `docker rm -f <container>`, so this kills a running
container and removes it in one step rather than refusing to touch it. There is
no `--yes` on this verb: it acts immediately, on the first try. The container's
writable layer goes with it, and anything the container wrote outside a volume
or a bind mount is gone. Named volumes survive, because `-v` is never passed.

Runs under a 120 second ceiling. Failure exits 1 with docker's stderr as the
hint. This is the Docker window's remove button, running the same command.

### `ed machines docker pause`

Freezes a container's processes without stopping it.

```
ed machines docker pause [--json] <machine> <container>...
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<container>...` | one or more container names or ids | at least one required | Which containers to freeze. Docker is given all of them in one call. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "action": "pause",
  "containers": [
    "open-webui"
  ],
  "machine": "Asus TUF 7"
}
```

#### Examples

```
ed machines tuf docker pause open-webui
ed machines tuf docker pause open-webui --json
```

#### Behaviour notes

Runs `docker pause <container>` under a 120 second ceiling. The container keeps
its memory and its ports; its processes simply stop being scheduled.

A paused container reports `state: "paused"`, which `ed machines docker ps`
counts as not running, so it vanishes from a bare `ps` and only reappears with
`--all`. Pausing something already paused is an error on docker's side and exits
1.

### `ed machines docker unpause`

Lets a frozen container run again.

```
ed machines docker unpause [--json] <machine> <container>...
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<container>...` | one or more container names or ids | at least one required | Which containers to resume. Docker is given all of them in one call. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "action": "unpause",
  "containers": [
    "open-webui"
  ],
  "machine": "Asus TUF 7"
}
```

#### Examples

```
ed machines tuf docker unpause open-webui
ed machines tuf docker unpause open-webui --json
```

#### Behaviour notes

Runs `docker unpause <container>` under a 120 second ceiling. Unpausing a
container that is not paused exits 1 with docker's complaint as the hint.

### `ed machines docker rmi`

Removes an image. Also answers to `remove-image`.

```
ed machines docker rmi [--json] [--force] <machine> <image>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<image>` | image name, `repository:tag`, or an id from `ed machines docker images` | required | Which image to remove. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--force` | flag | off | Remove it even when a container still refers to it. Adds `-f` to the docker command. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Human output is one line, `removed image <image>`.

#### `--json` shape

```json
{
  "forced": false,
  "image": "postgres:16",
  "machine": "Asus TUF 7"
}
```

`forced` records whether you passed `--force`, not whether force was needed.
`image` is echoed back as you typed it.

#### Examples

```
ed machines tuf docker rmi postgres:16
ed machines tuf docker rmi de3a4eab8fdf --force
ed machines tuf docker remove-image postgres:16 --json
```

#### Behaviour notes

Runs `docker image rm [-f] <image>` under a 120 second ceiling. There is no
`--yes` on this verb, which is deliberate: an image is re-pullable, unlike a
volume.

Without `--force`, docker refuses to remove an image a container still refers
to, even a stopped one, and that refusal becomes exit 1 with docker's message as
the hint. With `--force` docker untags it and removes it when nothing else holds
the layers. Removing an image that several tags point at removes only the tag
you named unless you pass an id.

This is the Docker window's image delete button, which always runs the
unforced form.

### `ed machines docker volume-rm`

Removes a volume and everything in it. Does nothing without `--yes`.

```
ed machines docker volume-rm [--json] [--yes] <machine> <volume>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<volume>` | volume name, exactly as `ed machines docker volumes` prints it | required | Which volume to remove. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the human lines. |
| `--yes` | flag | off | Actually remove it. Without this nothing is touched. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Without `--yes` the command says what it would do and exits 0. The refusal note
goes to stderr, so a script reading stdout sees only the plan:

```
$ ed machines tuf docker volume-rm pg_data
would remove volume pg_data and everything in it
nothing was removed; pass --yes to go ahead
```

#### `--json` shape

The same three keys in both directions. `removed` is the one that changes:

```json
{
  "machine": "Asus TUF 7",
  "removed": false,
  "volume": "pg_data"
}
```

With `--yes`, and after docker agreed:

```json
{
  "machine": "Asus TUF 7",
  "removed": true,
  "volume": "pg_data"
}
```

#### Examples

```
ed machines tuf docker volume-rm pg_data
ed machines tuf docker volume-rm pg_data --json
ed machines tuf docker volume-rm pg_data --yes
```

#### Behaviour notes

A volume is where a container keeps the data it means to survive a restart, so
this is the one container operation with nothing behind it: no trash, no undo,
no copy on the machine. `--yes` exists for that reason, and the dry run is the
default rather than an option.

With `--yes` the remote command is `docker volume rm <volume>`, under a 120
second ceiling. Docker refuses to remove a volume a container still refers to,
even a stopped one, and that refusal is exit 1 with docker's message as the
hint; remove or recreate the container first. There is no force flag here.

The dry run is not free: `ed` still opens the connection and checks that docker
is usable before it prints the plan, so `volume-rm` without `--yes` against an
unreachable machine exits 4 rather than 0.

### `ed machines docker prune`

Reclaims space by removing unused docker objects. Does nothing without `--yes`.

```
ed machines docker prune [--json] [--yes] <machine> [<what>]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<what>` | `images`, `volumes`, `networks`, `builder` or `system` | `system` | Which family of unused objects to remove. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the human lines. |
| `--yes` | flag | off | Actually prune. Without it nothing is removed. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Each target maps to exactly one docker command, and the dry run prints it:

| `<what>` | Command | What goes |
| --- | --- | --- |
| `images` | `docker image prune -af` | Every image no container uses, not just the dangling ones. |
| `volumes` | `docker volume prune -f` | Every volume no container uses, and the data in it. |
| `networks` | `docker network prune -f` | Every user-defined network nothing is attached to. |
| `builder` | `docker builder prune -af` | The whole build cache. |
| `system` | `docker system prune -f` | Stopped containers, unused networks, dangling images and build cache. Volumes are not included. |

```
$ ed machines tuf docker prune
would run: docker system prune -f
pass --yes to do it
```

#### `--json` shape

The two shapes differ, which is worth knowing before you parse them. The dry run
reports the command it would have run:

```json
{
  "applied": false,
  "command": "docker image prune -af",
  "machine": "Asus TUF 7",
  "target": "images"
}
```

The applied run reports what docker said instead:

```json
{
  "applied": true,
  "machine": "Asus TUF 7",
  "output": "Total reclaimed space: 3.585GB",
  "target": "images"
}
```

`command` is present only when `applied` is false, and `output` only when it is
true. `output` is docker's stdout with leading and trailing whitespace trimmed,
which for a real prune is a list of deleted ids followed by the reclaimed total.
Without `--json` that same stdout is printed raw.

#### Examples

```
ed machines tuf docker prune
ed machines tuf docker prune images --json
ed machines tuf docker prune builder --yes
ed machines tuf docker prune volumes --yes
```

#### Behaviour notes

The target is checked before anything else happens, including before the
connection is opened, so a typo costs nothing and exits 3 with the valid list:

```
$ ed machines tuf docker prune everything
error: docker cannot prune everything
hint: try: images, volumes, networks, builder, system
```

`volumes` is spelled out as its own target rather than folded into `system` on
purpose. `docker system prune` does not touch volumes unless it is asked to, and
`ed` never asks it to, so the only way to lose volume data here is to type
`prune volumes --yes`.

`prune images` is more aggressive than `docker image prune` typed by hand. The
`-a` means every image without a container, not only the untagged ones, so a
tagged image you pulled for later goes too. Check
`ed machines docker df --json` first: the `Images` row's `reclaimableBytes` is
what this will free.

With `--yes` the ceiling is 300 seconds, longer than any container verb here and
second only to `compose pull`. A prune that outruns it is reported as a failure
while docker keeps going on the machine.

### `ed machines docker compose ls`

Lists the compose projects on the machine. Also answers to `list`, and runs when
you name no compose subcommand.

```
ed machines docker compose ls [--json] <machine>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the plain lines. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Human output is one project name per line. With no projects, the message goes to
stderr and stdout stays empty:

```
$ ed machines tuf docker compose ls
no compose projects on Asus TUF 7
```

#### `--json` shape

A top-level array of strings, and `[]` rather than nothing when there are none:

```json
[
  "noveum-local-db"
]
```

Only the project name is reported. The status and config file path that
`docker compose ls` also prints are parsed away.

#### Examples

```
ed machines tuf docker compose ls
ed machines tuf docker compose list --json
ed machines tuf docker compose ls --json | jq -r '.[]'
```

#### Behaviour notes

Read only, 30 second ceiling, `docker compose ls --format json 2>/dev/null`.
Note the missing `-a`: docker lists only projects that are currently running, so
a project whose containers are all stopped does not appear here even though its
containers still exist. That is not cosmetic, because every other compose verb
refuses a project this command did not list.

To see the stopped ones, ask docker directly through the raw form:

```
$ ed tuf 'docker compose ls -a --format json'
[{"Name":"noveum-local-db","Status":"exited(3)","ConfigFiles":"/home/pulkit/Desktop/noveum-app-nextjs/extras/db/docker-compose.local-db.yml"}]
```

A machine whose docker has no compose plugin fails rather than reporting
nothing. Compose's complaint is discarded by the `2>/dev/null`, but its non-zero
status is not, so you get exit 1 naming the command that failed and an empty
hint:

```
$ ed machines old-box docker compose ls
error: docker compose ls --format json 2>/dev/null exited 1 on old-box
hint:
```

### `ed machines docker compose up`

Brings a compose project up in the background.

```
ed machines docker compose up [--json] <machine> <project>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<project>` | compose project name, exactly as `compose ls` prints it | required | Which project to bring up. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Human output is one line, `up -d <project>`.

#### `--json` shape

```json
{
  "action": "up -d",
  "machine": "Asus TUF 7",
  "project": "noveum-local-db"
}
```

`action` carries the compose action as it was sent, so it reads `up -d` rather
than `up`.

#### Examples

```
ed machines tuf docker compose up noveum-local-db
ed machines tuf docker compose up noveum-local-db --json
```

#### Behaviour notes

The project name is checked against `compose ls` before anything runs, and an
unknown one exits 3 with the projects that do exist as the hint, or with a nudge
to look again when there are none:

```
$ ed machines tuf docker compose up noveum-local-db
error: no compose project named noveum-local-db on Asus TUF 7
hint: run `ed machines Asus TUF 7 docker compose ls` to look again
```

That is the common failure, and it is usually not a typo: `compose ls` lists
only running projects, so a project that is fully down cannot be named here.
Bring it up through the raw form, from the directory that holds its file:
`ed tuf 'cd /srv/app && docker compose up -d'`.

The remote command is `docker compose -p <project> up -d`, run from the SSH
login directory, with no `-f` and no `--project-directory`. Compose has to be
able to find the project's configuration from there; when it cannot, its own
message comes back as the hint on an exit 1. The ceiling is 300 seconds.

There is no Docker window equivalent for this verb. The window groups containers
by compose project but never runs compose itself.

### `ed machines docker compose down`

Takes a compose project down.

```
ed machines docker compose down [--json] <machine> <project>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<project>` | compose project name, exactly as `compose ls` prints it | required | Which project to take down. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "action": "down",
  "machine": "Asus TUF 7",
  "project": "noveum-local-db"
}
```

#### Examples

```
ed machines tuf docker compose down noveum-local-db
ed machines tuf docker compose down noveum-local-db --json
```

#### Behaviour notes

The remote command is `docker compose -p <project> down`, with a 300 second
ceiling and the same project check `up` performs. `down` removes the project's
containers and its default network. Named volumes survive: `-v` is never passed,
and there is no flag here that would pass it. To remove a project's data as
well, list its volumes with `ed machines docker volumes` and take them with
`ed machines docker volume-rm --yes`.

After a successful `down` the project disappears from `compose ls`, so the
matching `up` through `ed` will not find it. That round trip is the reason to
prefer the raw form for projects you take all the way down.

### `ed machines docker compose restart`

Restarts a compose project.

```
ed machines docker compose restart [--json] <machine> <project>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<project>` | compose project name, exactly as `compose ls` prints it | required | Which project to restart. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "action": "restart",
  "machine": "Asus TUF 7",
  "project": "noveum-local-db"
}
```

#### Examples

```
ed machines tuf docker compose restart noveum-local-db
ed machines tuf docker compose restart noveum-local-db --json
```

#### Behaviour notes

Runs `docker compose -p <project> restart` with a 300 second ceiling, after the
same project check. This restarts the existing containers rather than recreating
them, so a changed compose file has no effect: that needs `up`. The Docker
window restarts containers one at a time and never a whole project, so this verb
has no button behind it.

### `ed machines docker compose pull`

Pulls the images a compose project uses.

```
ed machines docker compose pull [--json] <machine> <project>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to act on. |
| `<project>` | compose project name, exactly as `compose ls` prints it | required | Whose images to pull. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the one-line confirmation. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "action": "pull",
  "machine": "Asus TUF 7",
  "project": "noveum-local-db"
}
```

#### Examples

```
ed machines tuf docker compose pull noveum-local-db
ed machines tuf docker compose pull noveum-local-db --json
```

#### Behaviour notes

Runs `docker compose -p <project> pull` with a 900 second ceiling, the longest
on this page, because pulling several images over a slow link is the one thing
here that legitimately takes a quarter of an hour. Progress is not streamed:
compose's output is collected and discarded on success, and only the
confirmation line is printed. Pass through `ed tuf 'cd /srv/app && docker
compose pull'` if you want to watch it.

Pulling needs the compose file, so this is the other verb, with `up`, that
depends on compose finding the project's configuration from the login directory.

### `ed machines docker compose logs`

Streams the logs of every container in a compose project.

```
ed machines docker compose logs [--tail <n>] [--follow] <machine> <project>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias, id, or any unambiguous prefix | required | Which machine to ask. |
| `<project>` | compose project name, exactly as `compose ls` prints it | required | Whose logs to stream. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--tail` | integer, 0 or more | `200` | How many trailing lines to show, per service. |
| `--follow`, `-f` | flag | off | Keep streaming until interrupted. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

There is no `--json`, and unlike `ed machines docker logs` there are no
timestamps: compose prefixes each line with the service name instead.

#### Examples

```
ed machines tuf docker compose logs noveum-local-db
ed machines tuf docker compose logs noveum-local-db --tail 20
ed machines tuf docker compose logs noveum-local-db --tail 0 --follow
```

#### Behaviour notes

The remote command is `docker compose -p <project> logs --tail <n> [-f]`, after
the same project check the other compose verbs make, so an unlisted project
exits 3 before anything streams. `--tail` is validated first and a negative
value exits 2.

Like `ed machines docker logs`, this is a passthrough: stdout and stderr stay
separate, there is no timeout, and the remote exit code becomes yours.

## Exit codes

| Code | When |
| --- | --- |
| 0 | The command did what it said. A dry run of `prune` or `volume-rm` also exits 0, having changed nothing, and so do `--help` and `--version`. |
| 1 | Docker ran and refused, or failed: no such container, an image still in use, a volume still attached, a compose file compose could not find. The message names the verb and the machine, and docker's own stderr is the hint. Also a remote command that outran its timeout, and a `logs` stream whose `ssh` would not start. |
| 2 | `--tail` was negative, or the command line was wrong in the ordinary way: an unknown flag, a missing `<machine>` or `<container>`, a `--tail` that is not a number. |
| 3 | The machine name matched nothing or matched several; `<what>` was not one of the five prune targets; `<project>` was not in `compose ls`; `inspect` got a zero status and no output. |
| 4 | The machine could not be reached, docker on it is not usable (not installed, the daemon down, or this user cannot talk to the socket), or `ssh` itself could not be launched for a non-streaming command. |
| other | `logs` and `compose logs` propagate the remote process's own exit code verbatim, so anything docker returns reaches you unchanged. |

The docker availability failures all read the same way, with the specific reason
as the hint:

```
error: docker is not usable on Asus TUF 7
hint: docker is not installed there
```

The other hints on that message are `this user cannot talk to the docker
socket`, `The Docker daemon is not running.` and, when docker answered with
something unrecognisable, `docker reported an unknown state`.

## Notes and gotchas

- Word order is free. `ed machines tuf docker ps` and
  `ed machines docker ps tuf` are the same invocation: the machine is rewritten
  into the position the parser expects. A subcommand name always wins, so a
  machine literally called `docker` has to be named as
  `ed machines show docker`.
- `ed tuf docker ps` is not this page. Naming a machine as the first word makes
  the rest a raw remote command, so that line runs docker's own `ps` on the
  machine and prints docker's own table. Add `machines` to get the parsed form.
  This is the escape hatch for everything not covered here: `ed tuf docker
  buildx ls`, `ed tuf docker exec -it api sh`.
- `ed machines docker <machine>` with no verb is `ps`, and
  `ed machines docker compose <machine>` with no verb is `compose ls`.
- There is no `ed machines docker exec`. The Docker window's shell button is
  `ed machines exec --tty <machine> 'docker exec -it <container> sh'`, and
  `--tty` is what makes an interactive shell work at all.
- Every verb, including both dry runs, starts by running
  `docker version --format '{{json .}}'` on the machine with a 25 second ceiling
  and refusing to go on unless the daemon answered. That is the one round trip
  you pay for before anything else happens, and it is why an unreachable machine
  exits 4 even for a command that would have changed nothing.
- Docker commands always run in the SSH login directory. The remembered `cd`
  that `ed <machine> cd ...` sets belongs to `ed machines exec` and does not
  reach this page, which is why the compose verbs pass a project name rather
  than a directory.
- The timeouts are per command: 25 seconds for the version probe, 45 for `ps`,
  `images`, `volumes` and `df`, 30 for `networks`, `inspect` and `compose ls`,
  120 for every container lifecycle verb and for `rmi` and `volume-rm`, 300 for
  `prune` and for `compose up`, `down` and `restart`, 900 for `compose pull`.
  `logs` and `compose logs` have none. A command that outruns its ceiling has
  its `ssh` sent `SIGTERM`, then `SIGKILL` two seconds later, and surfaces as
  exit 1 while the work carries on unsupervised on the machine.
- `--json` output is one document per invocation, keys sorted, two space indent.
  Nothing on this page streams JSON, and nothing here takes `--json --follow`.
- Three verbs have no `--json` at all: `logs`, `inspect` and `compose logs`.
  `inspect` does not need one, since its output is already docker's JSON.
- The container id you pass is never resolved by `ed`. Names, short ids and full
  ids all go to docker as typed, so docker's own matching rules apply, including
  its refusal when a short id is ambiguous.
- `ps --json` drops two fields it collects. Network rx and tx bytes are parsed
  out of `docker stats` and never reach the document; only CPU and memory do.
- Volume sizes are never reported by `volumes`. Use `df`.
- Every mutating verb here is claimed by a Docker window action except the four
  compose lifecycle verbs, which the window does not have: it groups containers
  by compose project but never runs compose.
- Some hints embed the machine's display name unquoted, so a machine whose name
  has spaces produces a hint you cannot paste as is. Use the ssh alias, `tuf`,
  or any unambiguous prefix instead.
- These commands never need Edith to be running, and never ask macOS for a
  permission. Everything they touch is on the other machine.

## Where to go next

- [`ed machines`](./machines.md) for the machine directory itself, connecting
  and disconnecting, and `ed machines metrics` for the host the containers run
  on.
- [Running commands on a machine](./machines-remote.md) for the raw form,
  `--tty`, and everything docker can do that this page does not parse.
- [`ed machines files`](./machines-files.md) for the compose files and bind
  mounts behind these projects.
- [`ed machines power`](./machines-power.md) for the systemd unit that starts
  docker, and for the machine's own power state.
- [Conventions and contracts](./conventions.md) for the exit code table and the
  `--json` guarantees these commands follow.
- [The `ed` command line](./README.md) for the rest of the reference.
