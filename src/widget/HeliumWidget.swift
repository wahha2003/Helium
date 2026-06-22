import WidgetKit
import SwiftUI

struct HUDEntry: TimelineEntry {
    let date: Date
}

struct HUDTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HUDEntry {
        HUDEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (HUDEntry) -> Void) {
        completion(HUDEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HUDEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [HUDEntry(date: Date())], policy: .after(next)))
    }
}

struct HUDWidgetView: View {
    let entry: HUDEntry

    var body: some View {
        VStack {
            Image(systemName: "bolt.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text("Helium")
                .font(.caption)
        }
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
