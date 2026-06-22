import WidgetKit
import SwiftUI

struct HUDEntry: TimelineEntry {
    let date: Date
    let launched: Bool
}

struct HUDTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HUDEntry {
        HUDEntry(date: Date(), launched: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (HUDEntry) -> Void) {
        completion(HUDEntry(date: Date(), launched: SpawnHUDIfNeeded()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HUDEntry>) -> Void) {
        let ok = SpawnHUDIfNeeded()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [HUDEntry(date: Date(), launched: ok)], policy: .after(next)))
    }
}

struct HUDWidgetView: View {
    let entry: HUDEntry

    var body: some View {
        Image(systemName: entry.launched ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundColor(entry.launched ? .green : .red)
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HeliumLaunchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeliumHUD", provider: HUDTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                HUDWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                HUDWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Helium")
        .description("Launch HUD")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct HeliumWidgetBundle: WidgetBundle {
    var body: some Widget {
        HeliumLaunchWidget()
    }
}
