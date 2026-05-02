import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct HUDStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> HUDStatusEntry {
        HUDStatusEntry(date: Date(), isRunning: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (HUDStatusEntry) -> Void) {
        let isRunning = WidgetIsHUDRunning()
        completion(HUDStatusEntry(date: Date(), isRunning: isRunning))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HUDStatusEntry>) -> Void) {
        let autoStart = WidgetGetAutoStartEnabled()
        var isRunning = WidgetIsHUDRunning()

        if !isRunning && autoStart {
            WidgetLaunchHUD()
            Thread.sleep(forTimeInterval: 1.0)
            isRunning = WidgetIsHUDRunning()
        }

        let entry = HUDStatusEntry(date: Date(), isRunning: isRunning)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct HUDStatusEntry: TimelineEntry {
    let date: Date
    let isRunning: Bool
}

// MARK: - Widget View

struct HeliumWidgetView: View {
    let entry: HUDStatusEntry

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: entry.isRunning ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundColor(entry.isRunning ? .green : .orange)
                .font(.title2)
            Text(entry.isRunning ? "HUD Running" : "HUD Stopped")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget Declaration

struct HeliumLaunchWidget: Widget {
    let kind = "HeliumLaunchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HUDStatusProvider()) { entry in
            if #available(iOS 17.0, *) {
                HeliumWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                HeliumWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Helium HUD")
        .description("Auto-start HUD service at boot")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct HeliumWidgetBundle: WidgetBundle {
    var body: some Widget {
        HeliumLaunchWidget()
    }
}
