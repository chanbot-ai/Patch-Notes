import SwiftUI

struct NotificationsInboxView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onOpenNotificationPost: @MainActor (AppNotification) -> Void
    @State private var selectedFilter: NotificationsFilter = .all

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(NotificationsFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if store.notificationsIsLoading && store.notifications.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Loading notifications…")
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if let errorMessage = store.notificationsErrorMessage, store.notifications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications failed to load")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        store.loadNotifications()
                    }
                }
                .foregroundStyle(.red)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if !store.notificationsIsLoading && store.notificationsErrorMessage == nil {
                if filteredNotifications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedFilter.emptyStateTitle)
                            .font(.headline)
                        Text(selectedFilter.emptyStateMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(notificationSections) { section in
                        Section(section.title) {
                            ForEach(section.notifications) { notification in
                                Button {
                                    store.markNotificationRead(notification.id)
                                    if notification.postID != nil {
                                        onOpenNotificationPost(notification)
                                    }
                                } label: {
                                    NotificationRow(
                                        notification: notification,
                                        actorProfile: store.notificationActorProfile(for: notification.actorUserID)
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .textCase(nil)
                        .listSectionSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if store.unreadNotificationsCount > 0 {
                    Button("Mark All Read") {
                        store.markAllNotificationsRead()
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        }
        .refreshable {
            await store.refreshNotifications()
        }
        .task {
            if store.notifications.isEmpty && !store.notificationsIsLoading {
                store.loadNotifications()
            }
        }
    }

    private var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return store.notifications
        case .unread:
            return store.notifications.filter { !$0.isRead }
        }
    }

    private var notificationSections: [NotificationSection] {
        let calendar = Calendar.current
        let sorted = filteredNotifications.sorted { $0.createdAt > $1.createdAt }
        var today: [AppNotification] = []
        var yesterday: [AppNotification] = []
        var thisWeek: [AppNotification] = []
        var earlier: [AppNotification] = []

        for notification in sorted {
            let date = notification.createdAt
            if calendar.isDateInToday(date) {
                today.append(notification)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(notification)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
                thisWeek.append(notification)
            } else {
                earlier.append(notification)
            }
        }

        var sections: [NotificationSection] = []
        if !today.isEmpty {
            sections.append(NotificationSection(title: "Today", notifications: today))
        }
        if !yesterday.isEmpty {
            sections.append(NotificationSection(title: "Yesterday", notifications: yesterday))
        }
        if !thisWeek.isEmpty {
            sections.append(NotificationSection(title: "This Week", notifications: thisWeek))
        }
        if !earlier.isEmpty {
            sections.append(NotificationSection(title: "Earlier", notifications: earlier))
        }
        return sections
    }
}

private enum NotificationsFilter: String, CaseIterable, Identifiable {
    case all
    case unread

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .all:
            return "No notifications yet"
        case .unread:
            return "You're all caught up"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .all:
            return "Comments and replies on your posts will show up here."
        case .unread:
            return "Unread notifications will show up here when new activity arrives."
        }
    }
}

private struct NotificationSection: Identifiable {
    let id = UUID()
    let title: String
    let notifications: [AppNotification]
}

private struct NotificationRow: View {
    let notification: AppNotification
    let actorProfile: PublicProfile?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(notification.isRead ? Color.white.opacity(0.16) : AppTheme.accent)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(notification.titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(notification.isRead ? 0.78 : 0.95))
                    if !notification.isRead {
                        Text("NEW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    }
                    Spacer(minLength: 0)
                    Text(compactRelativeTimestamp(notification.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Text(notificationMessageText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(notification.isRead ? 0.03 : 0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(notification.isRead ? Color.white.opacity(0.06) : AppTheme.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private var notificationMessageText: String {
        if notification.type.hasPrefix("badge_unlock:") {
            return notification.bodyText
        }
        if let actorProfile {
            let actorName = actorProfile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let actor = (actorName?.isEmpty == false ? actorName! : actorProfile.username)
            switch notification.type {
            case "comment_reply":
                return "\(actor) replied to your comment."
            case "post_comment":
                return "\(actor) commented on your post."
            default:
                return "\(actor) interacted with your content."
            }
        }
        return notification.bodyText
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Notifications - Empty") {
    let store = AppStore()
    return NavigationStack {
        NotificationsInboxView(onOpenNotificationPost: { _ in })
            .environmentObject(store)
    }
    .preferredColorScheme(.dark)
}

#Preview("Notifications - Populated") {
    let actorID = UUID(uuidString: "22222222-0000-0000-0000-000000000002")!
    let actor = PreviewHelpers.makeProfile(id: actorID, username: "galacticat", displayName: "Galacticat")
    let notifications = [
        PreviewHelpers.makeNotification(type: "post_comment", read: false, createdAt: Date().addingTimeInterval(-1800)),
        PreviewHelpers.makeNotification(type: "comment_reply", read: false, createdAt: Date().addingTimeInterval(-7200)),
        PreviewHelpers.makeNotification(type: "post_comment", read: true, createdAt: Date().addingTimeInterval(-90000)),
        PreviewHelpers.makeNotification(type: "comment_reply", read: true, createdAt: Date().addingTimeInterval(-180000))
    ]
    let store = AppStore()
    store.seedPreviewState(AppPreviewState(
        notifications: notifications,
        notificationActorProfilesByID: [actorID: actor]
    ))
    return NavigationStack {
        NotificationsInboxView(onOpenNotificationPost: { _ in })
            .environmentObject(store)
    }
    .preferredColorScheme(.dark)
}
#endif
