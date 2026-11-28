// Perf driver (contract S1-06 §3, SA-S6-8): the
// single settled pattern. integrationDriver with a
// responseDataCallback that summarizes the timeline
// the perf test recorded under the 'timeline' key
// (traceAction, reportKey: 'timeline') into
// build/timeline.timeline_summary.json — matching
// the build/*timeline_summary.json glob of
// MUSE_STEPS §S1-06, where
// 90th_percentile_frame_build_time_millis and
// 90th_percentile_frame_rasterizer_time_millis
// are read. The numbers are the emulator gate's
// and are labelled "indicative" (SA-S6-1): the
// real-device gate lives outside S1-06.
//
// The 'touch_to_image_ms' key (SA-S6-4) rides in
// the same response data and is ignored here — it
// is a recorded metric (drive log + progress), not
// a gate, and not part of the timeline summary.
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      final timelineJson = data['timeline'];
      if (timelineJson is Map<String, dynamic>) {
        final timeline = driver.Timeline.fromJson(timelineJson);
        final summary = driver.TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile('timeline', pretty: true);
      }
    },
  );
}
