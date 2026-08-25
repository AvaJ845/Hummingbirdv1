import WidgetKit
import SwiftUI

@main
struct HummingbirdWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchlistWidget()
        TrackRecordWidget()
        PortfolioWidget()
        SketchLiveActivity()
    }
}
