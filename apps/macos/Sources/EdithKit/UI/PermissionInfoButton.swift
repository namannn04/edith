import SwiftUI

public struct PermissionInfoButton: View {
    private let permissions: [ExtensionPermission]
    private let label: String?
    private let color: Color
    @State private var showing = false

    public init(
        permissions: [ExtensionPermission], label: String? = nil, color: Color = .secondary
    ) {
        self.permissions = permissions
        self.label = label
        self.color = color
    }

    public init(_ permission: ExtensionPermission) {
        permissions = [permission]
        label = nil
        color = .secondary
    }

    public var body: some View {
        Button {
            showing.toggle()
        } label: {
            if let label {
                HStack(spacing: 4) {
                    Text(label)
                    Image(systemName: "info.circle")
                }
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
            } else {
                Image(systemName: "info.circle")
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .pointerCursor()
        .accessibilityLabel("Permission details")
        .help("Permission details")
        .popover(isPresented: $showing, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(permissions, id: \.self) { permission in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(permission.displayName)
                            .font(.caption.weight(.semibold))
                        Text(permission.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 280, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
        }
    }
}
