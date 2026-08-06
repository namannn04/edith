import Foundation

public enum DockerCommands {
    public static let jsonFormat = "{{json .}}"
    public static let listSeparator = "@EDITHSPLIT@"

    public static func version() -> String {
        "docker version --format \(ShellQuote.quote(jsonFormat)) 2>&1"
    }

    public static func composeVersion() -> String {
        "docker compose version --short"
    }

    public static func containersWithStats() -> String {
        let ps = "docker ps -a --no-trunc --format \(ShellQuote.quote(jsonFormat))"
        let stats =
            "docker stats --no-stream --format \(ShellQuote.quote(jsonFormat)) 2>/dev/null"
        return "\(ps); echo \(ShellQuote.quote(listSeparator)); \(stats)"
    }

    public static func images() -> String {
        "docker images --no-trunc --format \(ShellQuote.quote(jsonFormat))"
    }

    public static func volumes() -> String {
        "docker volume ls --format \(ShellQuote.quote(jsonFormat))"
    }

    public static func networks() -> String {
        "docker network ls --format \(ShellQuote.quote(jsonFormat))"
    }

    public static func diskUsage() -> String {
        "docker system df --format \(ShellQuote.quote(jsonFormat))"
    }

    public static func diskUsageVerbose() -> String {
        "docker system df -v --format \(ShellQuote.quote(jsonFormat))"
    }

    public static func inspect(_ id: String) -> String {
        "docker inspect --format \(ShellQuote.quote(jsonFormat)) \(ShellQuote.quote(id))"
    }

    public static func logs(_ id: String, tail: Int, follow: Bool) -> String {
        var command = "docker logs --timestamps --tail \(tail)"
        if follow { command += " --follow" }
        return command + " " + ShellQuote.quote(id)
    }

    public static func lifecycle(_ action: String, id: String) -> String {
        switch action {
        case "stop", "restart":
            return "docker \(action) -t 10 \(ShellQuote.quote(id))"
        case "rm":
            return "docker rm -f \(ShellQuote.quote(id))"
        default:
            return "docker \(action) \(ShellQuote.quote(id))"
        }
    }

    public static func removeImage(_ id: String, force: Bool) -> String {
        "docker image rm \(force ? "-f " : "")\(ShellQuote.quote(id))"
    }

    public static func pullImage(_ reference: String) -> String {
        "docker pull \(ShellQuote.quote(reference))"
    }

    public static func pruneImages() -> String {
        "docker image prune -f"
    }

    public static func removeVolume(_ name: String) -> String {
        "docker volume rm \(ShellQuote.quote(name))"
    }

    public static func pruneVolumes() -> String {
        "docker volume prune -f"
    }

    public static func composeAction(_ action: String, project: String) -> String {
        "docker compose -p \(ShellQuote.quote(project)) \(action)"
    }

    public static func execShell(containerID: String) -> String {
        let inner =
            "command -v bash >/dev/null 2>&1 && exec bash || exec sh"
        return "docker exec -it \(ShellQuote.quote(containerID)) sh -c \(ShellQuote.quote(inner))"
    }
}
