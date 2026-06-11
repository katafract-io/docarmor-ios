// AppGroupDiagnosticsView.swift
// DocArmor
//
// Runtime App Group entitlement check. Surfaces connection state and
// shared UserDefaults values — catches provisioning profile mismatches
// that source-level audits can't detect.

import SwiftUI

struct AppGroupDiagnosticsView: View {
    private let groupID = "group.com.katafract.enclave"

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }
    private var suite: UserDefaults? { UserDefaults(suiteName: groupID) }
    private var plan: String? { suite?.string(forKey: "enclave.sigil.plan") }
    private var hasToken: Bool { suite?.string(forKey: "enclave.sigil.token") != nil }

    // The import inbox uses a DIFFERENT app group than the shared Enclave one
    // above. The section above only proves the Enclave group is provisioned;
    // shared-file imports depend on THIS group, so surface it too.
    private let inboxGroupID = AppGroup.identifier   // group.com.katafract.DocArmor
    private var inboxContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: inboxGroupID)
    }
    private var inboxFiles: [String] {
        guard let dir = inboxContainerURL?.appendingPathComponent(AppGroup.importInboxFolderName, isDirectory: true) else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    }

    var body: some View {
        Form {
            Section("Shared App Group") {
                LabeledContent("Group ID") { Text(groupID).font(.caption.monospaced()) }
                LabeledContent("Entitlement") {
                    Text(containerURL == nil ? "NOT CONNECTED" : "Connected")
                        .foregroundStyle(containerURL == nil ? .red : .green)
                        .font(.caption.weight(.semibold))
                }
                if let url = containerURL {
                    LabeledContent("Container") {
                        Text(url.lastPathComponent).font(.caption.monospaced()).lineLimit(1)
                    }
                }
            }

            Section("Sovereign State (from shared UserDefaults)") {
                LabeledContent("Plan") {
                    Text(plan ?? "—").font(.caption.monospaced())
                }
                LabeledContent("Token") {
                    Text(hasToken ? "Present" : "None")
                        .foregroundStyle(hasToken ? .green : .secondary)
                        .font(.caption.weight(.semibold))
                }
            }

            Section("Import Inbox Group (where shared files land)") {
                LabeledContent("Group ID") { Text(inboxGroupID).font(.caption.monospaced()).lineLimit(1) }
                LabeledContent("Entitlement") {
                    Text(inboxContainerURL == nil ? "NOT CONNECTED" : "Connected")
                        .foregroundStyle(inboxContainerURL == nil ? .red : .green)
                        .font(.caption.weight(.semibold))
                }
                LabeledContent("Files in inbox") { Text("\(inboxFiles.count)").font(.caption.weight(.semibold)) }
                ForEach(inboxFiles, id: \.self) { name in
                    Text(name).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Section {
                Text("If Entitlement shows 'NOT CONNECTED', the app binary was signed without the App Group. The provisioning profile needs to be regenerated in Apple Developer Portal and the app re-archived — re-checking the capability alone won't fix it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("App Group Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppGroupDiagnosticsView()
    }
}
