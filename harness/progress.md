# Progress — nhật ký harness

Định dạng: ngày, giai đoạn, ai làm, đã xong gì, kiểm chứng bằng gì, còn treo gì.

## 2026-11-28 — S2-03: test đã khóa (James)

- PR `test/S2-03`: `test/features/jigsaw_play/jigsaw_play_test.dart`
  tổng quát hoá helper theo gridSize (mặc định 3,
  ca cũ không đổi hành vi) + thêm nhóm S2-03
  (WID-JP-23..28: số mảnh/khay ở 4×4 và 6×6, kéo
  1 mảnh về home ở 6×6, chạm-chọn-chạm-đặt ở
  6×6, hoàn thành trọn 4×4, cỡ chữ 200% ở 6×6)
  — hash mới `48856354…`;
  `integration_test/perf_test.dart` tổng quát hoá
  helper theo `(gridSize, pieceCount)` + PERF-03
  (6×6, trace kéo 20 mảnh đầu về home, cùng
  reportKey `timeline`) — hash mới `907d956f…`;
  `test/features/word_play/word_play_test.dart`
  thêm WID-WP-12 (wiring chọn cỡ ở ModeSelect:
  mặc định 3, chip 6×6 → 6, chip 4×4 → 4) và sửa
  cơ học hai closure của WID-WP-10/11 cho chữ ký
  callback mới (khẳng định không đổi) — hash mới
  `669b7b2f…`. Cả ba khóa vào `harness/tests.lock`;
  pre-check `S2-03` OK ở giai đoạn test (verify
  tests lock OK). Bộ test tham chiếu chữ ký
  ModeSelect mới chưa tồn tại — đỏ biên dịch cho
  tới nhánh feat (đúng quy trình test-viết-trước).

## 2026-11-28 — S2-03: mở contract (James)

- `harness/contracts/S2-03.md`: ghi 6 chốt của
  Opus (comment `7240249925`, SA-J3-1..SA-J3-6,
  chốt theo khuyến nghị ở cổng `7240142808`) —
  lưới 4×4 và 6×6: ModeSelect thành Stateful giữ
  `_gridSize = 3`, hàng chip "3×3 | 4×4 | 6×6"
  nhãn "Grid size" phía trên 2 nút mode, callback
  mới `onJigsawSelected(int gridSize)` +
  `app.dart` nối `_startJigsaw(gs)` và Play again
  giữ nguyên cỡ đã chọn; KHÔNG đổi schema DB
  (khóa `(image_id, mode)`, best_time min chung —
  leaderboard theo cỡ cần thì migration riêng ở
  S3+, SA-J3-2); không lưu lựa chọn cỡ
  (SA-J3-3); PERF-03 kéo 20 mảnh đầu ở 6×6 trong
  profile mode, ngưỡng p90 build + rasterizer
  < 16 ms (`perf_03_p90_ms: 16` thêm vào
  thresholds.yaml ở PR này), số emulator vẫn
  indicative và cổng máy thật vẫn CHỜ máy của
  Paul (SA-J3-4); không đổi hình học, trayHeight
  112 mọi cỡ (SA-J3-5); bộ test WID-JP-23..28 +
  PERF-03, không IT giải trọn 6×6, không golden
  mới (SA-J3-6). Contract tự chốt thêm WID-WP-12
  cho wiring ModeSelect (verdict không kê ID
  riêng) và ghi rõ cập nhật cơ học ép buộc ở
  WID-WP-10/11 do đổi chữ ký callback — chờ Opus
  xác nhận khi soát chồng.
- Khối pre-check `S2-03` trong
  `tool/check_e_step.sh` + thêm `S2-03` vào
  `precheck_s2` trong `tool/evaluate.sh`. Ở giai
  đoạn contract, pre-check S2-03 fail đúng lý do
  đầu tiên (WID-JP-23 chưa khai báo — test viết ở
  nhánh test xếp chồng tiếp theo); các pre-check
  S2-01/S2-02 vẫn OK.

## 2026-11-28 — S2-02: code xong, evaluate xanh (James)

- PR `feat/S2-02-tap-place`: chỉ sửa 2 file
  theo SA-J2-8. `jigsaw_board_painter.dart` thêm
  field `selectedPieceId` (cửa sổ test như
  `hintCell`) + viền chọn 3 px `0xFF1565C0` ở ô
  board hoặc ô khay theo vị trí hiện tại của
  mảnh + `shouldRepaint`.
  `jigsaw_play_screen.dart`: trạng thái
  `int? _selectedPieceId`; máy trạng thái pointer
  thêm nhánh chạm — up với độ lệch lớn nhất
  ≤ 18 dp và chưa thành nhấc kéo long-press thì
  là chạm (chạm xuống ô board trống giờ cũng
  được theo dõi để nhận chạm đặt); chạm luôn
  tác động lên vật bị chạm (chọn/toggle/đổi
  chọn — đường chạm không sinh
  `rejectedOccupied`), ô đích của chạm là ô
  chứa điểm chạm (floor, không `snapTarget`);
  thả-kéo và chạm dùng chung một hàm resolve
  qua `PlacePiece` + một đường hoàn thành gọi
  `onCompleted` đúng 1 lần; chọn bị dọn khi
  drag thật di chuyển > 18 dp, khi đặt thành
  công qua chạm, hoặc khi chạm lại vật đang
  chọn; cuộn khay giữ chọn (nhánh cuộn không đi
  qua drag). Engine/constructor/`app.dart`
  không đổi; Semantics để S2-04 (SA-J2-10).
- Kiểm chứng tại máy: `evaluate.sh S2` PASS mọi
  cổng local (pre-check S2-01 + S2-02 OK, content
  validator PASS, purity PASS, tests lock PASS,
  analyze PASS, **227/227 test** = 217 cũ + 10
  WID-JP mới, engine coverage **92,4%**);
  `evaluate.sh S1` cũng PASS tương tự — không
  regress. Cổng integration fail tại máy chỉ vì
  "No devices are connected" (cổng CI — IT-J-07/08
  chạy ở android-it trên CI).

## 2026-11-28 — S2-02: test đã khóa (James)

- PR `test/S2-02`: `test/features/jigsaw_play/jigsaw_play_test.dart`
  thêm nhóm S2-02 (WID-JP-13..22: chọn ở khay,
  chạm lại bỏ chọn, đổi chọn, chạm ô trống đặt
  đúng/đặt sai, chạm occupant đổi chọn, chọn
  mảnh board + di chuyển bằng chạm, cuộn giữ
  chọn, kéo thật dọn chọn, giải trọn bằng chạm
  → `onCompleted` 1 lần) — hash mới của file
  `aee373ba…`; file mới
  `integration_test/jigsaw_tap_place_test.dart`
  (IT-J-07 giải trọn 3×3 chỉ bằng chạm, IT-J-08
  chọn → đặt sai → di chuyển lại bằng chạm —
  `737af033…`). Cả hai khóa vào
  `harness/tests.lock`; pre-check `S2-02` OK ở
  giai đoạn test (verify tests lock OK). Bộ test
  tham chiếu field `selectedPieceId` của painter
  chưa tồn tại — đỏ biên dịch cho tới nhánh feat
  (đúng quy trình test-viết-trước).

## 2026-11-28 — S2-02: mở contract (James)

- `harness/contracts/S2-02.md`: ghi 10 chốt của
  Opus (comment `7239396699`, SA-J2-1..SA-J2-10,
  chốt theo khuyến nghị ở cổng `7239258618`, một
  làm rõ: ca IT-J-08 bắt buộc) — chạm-chọn-chạm-đặt
  cho màn chơi: toggle chọn ở khay + trạng thái
  `selectedPieceId` qua painter, mảnh board cũng
  chọn/di chuyển bằng chạm (ngưỡng 18 dp), ô đích
  là ô chứa điểm chạm (không dùng `snapTarget`),
  không đường về khay, chạm luôn tác động lên vật
  bị chạm (đường chạm không sinh
  `rejectedOccupied`), cuộn giữ chọn + long-press
  giữ nguyên, hai đường cùng tồn tại với hàm
  resolve chung và 3 điểm dọn chọn, viền chọn
  3 px `0xFF1565C0`, chỉ sửa 2 file jigsaw_play
  (không constructor/engine/`app.dart` mới), bộ
  test WID-JP-13..22 + IT-J-07/08 với định nghĩa
  "không kéo" = không cử chỉ kéo nào áp lên mảnh,
  Semantics để S2-04.
- Khối pre-check `S2-02` trong
  `tool/check_e_step.sh` + thêm `S2-02` vào
  `precheck_s2` trong `tool/evaluate.sh`. Ở giai
  đoạn contract, pre-check S2-02 fail đúng lý do
  đầu tiên (file integration
  `jigsaw_tap_place_test.dart` chưa tồn tại) —
  test viết ở nhánh test xếp chồng tiếp theo.

## 2026-11-28 — S2-01: code xong, evaluate xanh (James)

- PR `feat/S2-01-word-play`: loader + model thêm
  `textEnWord`/`textEnAlt` (SA-WP-2/3); schema
  pipeline thêm `en_word`/`en_alt` vào whitelist
  của `text`; manifest a1p1 thêm `en_word` (không
  thêm `en_alt`); `ModeSelectScreen` mới (thumb +
  title, nút Words disable khi không có en_word);
  `WordPlayScreen` mới (một cột cuộn, chip nút
  thật key theo index+vùng, tự kiểm khi hàng đầy,
  notice `Not quite — try rearranging`, Stopwatch
  từ initState); shell nối đường vào qua mode
  select và handler hoàn thành mode `word`
  (markSolved trước CompletionScreen, Play again
  dựng màn word mới). Header hai màn mới có
  `errorBuilder` cho ảnh thumb (contract §14).
- Kiểm chứng tại máy: `evaluate.sh S2` PASS mọi
  cổng tất định (pre-check S2-01 OK, content
  validator PASS, purity PASS, tests lock PASS,
  analyze PASS, **217/217 test** = 199 cũ + 18
  mới, engine coverage **92,4%**); `evaluate.sh
  S1` cũng PASS tương tự — không regress. Cổng
  integration fail tại máy chỉ vì "No devices
  are connected" (Đ11 — cổng CI).
- Golden `word_play.png` sha256 `150c61ba…`
  (25.783 bytes) đã khóa trong tests.lock; PNG
  chờ phòng upload qua GitHub web UI lên nhánh
  test + feat (CI đỏ ở pre-check S2-01 tới khi
  PNG lên đủ hai nhánh — tiền lệ S1-03).

## 2026-11-28 — S2-01: test đã khóa (James)

- PR `test/S2-01`: `test/features/word_play/word_play_test.dart`
  (WID-WP-01..11, `5cfa9da6…`),
  `test/features/app_shell/word_completion_flow_test.dart`
  (INT-WP-01..03, `1c5a3744…`),
  `test/data/asset_loader_word_test.dart`
  (UNIT-AW-01..04, `2a0989c4…`) — khóa vào
  `harness/tests.lock`.
- Cập nhật cơ học theo SA-WP-1 (contract §14):
  INT-CS thêm một chạm "Jigsaw" sau thẻ Animals
  (`completion_flow_test.dart`, hash mới
  `20f8cfe8…`) và Maestro
  `persistence_restart.yaml` thêm `tapOn: "Jigsaw"`
  (hash mới `31d78ef2…`) — ID/kịch bản/assert khác
  không đổi, khóa hash lại.
- Golden `test/goldens/word_play.png`: sinh tại
  máy khi nhánh feat có màn hình, hash khóa bổ
  sung vào tests.lock trên nhánh test ngay sau
  đó; PNG đi đường GitHub web UI (không qua
  connector) như tiền lệ S1-03.

## 2026-11-28 — S2-01: mở contract (James)

- `harness/contracts/S2-01.md`: ghi 9 chốt của
  Opus (comment `7238524214`, SA-WP-1..SA-WP-9,
  chốt theo khuyến nghị ở cổng `7238401523`) —
  ModeSelectScreen sau khi chạm chủ đề (nút Words
  disable khi không có `text.en_word`), field
  `text.en_word` + `text.en_alt` vào
  schema/model/loader, tự kiểm tra khi hàng đáp
  án đầy (notice `Not quite — try rearranging`,
  không highlight từng token, không nút reset),
  chip hiện `WordToken.text` nguyên văn, một cột
  cuộn dọc (header thumb gọn → "Your sentence" →
  dòng trạng thái → "Word bank"), Stopwatch từ
  initState + CompletionScreen dùng lại +
  markSolved mode `word`, test WID-WP/INT-WP/
  UNIT-AW + golden `word_play.png`, Semantics
  chi tiết để S2-04.
- Khối pre-check `S2-01` trong
  `tool/check_e_step.sh` + `precheck_s2`/nhánh
  `S2` trong `tool/evaluate.sh`. Ở giai đoạn
  contract, pre-check S2-01 fail đúng lý do đầu
  tiên (màn word chưa tồn tại) — test viết ở
  nhánh test xếp chồng tiếp theo.
- Phụ lục contract ghi hai cập nhật cơ học ép
  buộc bởi SA-WP-1 (INT-CS + Maestro thêm một
  chạm "Jigsaw", làm ở nhánh test, khóa hash
  lại) và cách hiểu SA-WP-8 về file INT-CS.

## 2026-11-28 — S1-06: test đã khóa, sửa tràn chữ đã xong (James)

- PR `test/S1-06`: `integration_test/perf_test.dart`
  (PERF-01 `98afac35…`, PERF-02),
  `test_driver/perf_driver.dart` (`bfdb6a3a…`),
  `test/features/text_scale/text_scale_test.dart`
  (WID-FS-01..03, `7ece90bc…`) — tất cả khóa vào
  `harness/tests.lock`; `pubspec.yaml`/`pubspec.lock`
  khai báo trực tiếp `flutter_driver` (sdk) vào
  dev_dependencies (contract §3).
- Nhánh `feat/S1-06-perf-text-scale`: một sửa UI
  duy nhất, ép buộc bởi WID-FS-01 — thẻ chủ đề
  tràn đáy 16 px ở TextScaler 2.0 khi có dòng
  `<n> solved` (chiều cao cố định 72). Sửa:
  `ConstrainedBox(minHeight: 72)` + padding dọc 8
  + Stack căn giữa (contract S1-06 §11). WID-FS-02/03
  pass ngay trên code cũ — màn chơi và màn kết
  thúc không sửa gì. Golden `theme_select.png`
  PASS với PNG hiện có (hash giữ nguyên
  `4f435443…`, không sinh lại): ở tỉ lệ 1.0 thẻ
  vẫn cao 72 và chữ giữ nguyên vị trí.
- Kiểm chứng tại máy: `evaluate.sh S1` PASS mọi
  cổng trừ integration — pre-check S1-01..06 OK,
  content validator PASS, purity PASS, tests
  lock PASS, analyze PASS, **199/199 test** (196
  cũ + WID-FS-01..03), engine coverage **92,4%**.
  Cổng integration fail tại máy chỉ vì "No
  devices are connected" (Đ11 — cổng CI
  `android-it`); perf test thuộc cổng đó, tại máy
  đã kiểm analyze sạch + pre-check khai báo đủ
  PERF-01/02. Diff `test/` + `integration_test/` +
  `test_driver/` + tests.lock giữa nhánh test và
  feat: rỗng.
- **Perf (SA-S6-1)**: cổng emulator = indicative
  — chờ step CI của SA-S6-3 (diff trong contract
  §5) được áp qua web UI lên nhánh feat rồi CI
  chạy; số đầu tiên (gồm `touch_to_image_ms`,
  SA-S6-4 — chỉ ghi, không cổng) sẽ bổ sung vào
  progress sau. **Cổng máy thật: vẫn CHỜ máy của
  Paul** (mục mở contract bên dưới) — S1-06
  không đóng cổng này.
- **Đóng Phase S1 (SA-S6-7)**: chấm UX ≥ 8/10
  KHÔNG nằm trong chồng này. Sau khi chồng merge
  và các cổng tất định của S1 xanh, James đăng
  tổng kết đóng S1 kèm bằng chứng (golden + số
  perf indicative + kết quả WID-FS) để
  Claude/Opus chấm trên issue #2.

## 2026-11-28 — S1-06: mở contract (James)

- `harness/contracts/S1-06.md`: ghi 8 chốt của
  Opus (comment `7236919665`, SA-S6-1..SA-S6-8,
  chốt theo khuyến nghị ở cổng `7236776816`) —
  cổng emulator perf ghi nhãn **indicative**,
  cổng máy thật p90 < 16 ms giữ trạng thái **CHỜ
  (máy của Paul)** trong progress (xem mục dưới);
  kịch bản perf 3×3 trên puzzle thật `a1p1`
  (traceAction bao dãy kéo–đặt 9 mảnh + cuộn
  khay, helper IT-J; 6×6 để S2-03); mẫu driver
  duy nhất `traceAction(reportKey: 'timeline')`
  + `integrationDriver` xuất
  `build/*timeline_summary.json`; chỉ số phụ
  chạm → ảnh chỉ ghi, không cổng; test cỡ chữ
  WID-FS-01..03 cho cả 3 màn ở 320×568 dp +
  TextScaler 2.0; prefix PERF + pre-check S1-06;
  chấm UX đóng S1 không nằm trong chồng này
  (SA-S6-7, việc sau merge).
- Diff `ci.yml` của SA-S6-3 (step `flutter drive
  --profile` riêng sau bước integration test,
  `continue-on-error`, artifact timeline) ghi
  nguyên văn trong contract §5 — connector không
  đẩy được workflows nên phòng áp qua GitHub web
  UI lên nhánh feat sau khi đăng chồng (tiền lệ
  fix KVM của S1-04).
- Cùng PR: khối pre-check `S1-06` trong
  `tool/check_e_step.sh` + thêm vào `precheck_s1`
  của `tool/evaluate.sh`.
- Kiểm chứng tại máy: pre-check S1-06 fail đúng
  lý do đầu tiên (`integration_test/perf_test.dart`
  chưa có); S1-01..05 vẫn OK.
- **Cổng perf máy thật (SA-S6-1): CHỜ** — chờ
  Paul cung cấp máy Android cấu hình thấp chuẩn
  (model sẽ ghi vào `harness/thresholds.yaml`).
  S1-06 không tự đóng cổng này; số emulator là
  indicative, không thay thế.

## 2026-11-28 — S1-05: test đã khóa, completion đã code (James)

- PR `test/S1-05`: `completion_screen_test.dart`
  (WID-CP-01..06, `b8dc4c37…`),
  `completion_flow_test.dart` (INT-CS-01..03,
  `4614c7cd…`), WID-JP-10 cập nhật chữ ký
  `onCompleted(Duration)` theo SA-S5-4
  (`e55d6229…`), WID-TS-03 cập nhật nhãn SA-S5-6 +
  WID-TS-01b (`73c9b1c4…`),
  `.maestro/persistence_restart.yaml` (`7867448e…`)
  — tất cả khóa vào `harness/tests.lock`. Ba cập
  nhật ép buộc (contract S1-05 §12, khóa lại hash):
  hai integration test của S1-04 sửa cơ học theo
  chữ ký mới (`b6ae974a…`, `ad307c17…`) và
  UNIT-AL-12 cập nhật sang trạng thái content thật
  (`1339896e…`).
- Nhánh `feat/S1-05-completion`:
  `lib/features/completion/completion_screen.dart`
  (Semantics `Completed`, Time/Best `m:ss`, Play
  again qua callback của shell, Back to themes
  popUntil); Stopwatch + chữ ký `onCompleted` trong
  màn chơi; `lib/app.dart` thành StatefulWidget giữ
  MỘT `ProgressDao` dùng chung (SA-S5-5), seed
  `GAME_SEED` (SA-S5-2), handler hoàn thành:
  markSolved → pushReplacement CompletionScreen kể
  cả khi ghi lỗi, khóa asset `content/` + playPath;
  thẻ chủ đề hiện `<n> solved` + nhãn mới (SA-S5-6);
  `content/manifest.json` với puzzle thật `a1p1`
  ("Weaning the Calves", Rosa Bonheur 1879, The Met
  object 435703, CC0) + pubspec `- content/` và
  dòng pack riêng (thư mục asset không đệ quy — đã
  kiểm chứng bằng `flutter build bundle`); hai fix
  pipeline tồn đọng của S1-01 (validator nhận
  manifest dạng danh sách + pattern image_id nới
  ba dạng đã chốt) — validator PASS trên manifest
  thật, 25/25 test pipeline OK.
- Golden `theme_select.png`: kịch bản WID-TS-10
  mọi solvedCount = 0 nên render không đổi — test
  golden PASS với PNG hiện có, hash giữ nguyên
  `4f435443…`, không cần upload đợt này.
- Kiểm chứng tại máy: `evaluate.sh S1` PASS mọi
  cổng trừ integration — pre-check S1-01..05 OK,
  content validator PASS, purity PASS, tests lock
  PASS, analyze PASS, **196/196 test** (186 cũ +
  WID-CP-01..06 + INT-CS-01..03 + WID-TS-01b),
  engine coverage **92,4%**. Cổng integration fail
  tại máy chỉ vì "No devices are connected" (Đ11 —
  cổng CI `android-it`). Diff `test/` +
  `integration_test/` + `.maestro/` + tests.lock
  giữa nhánh test và feat: rỗng.
- **Maestro (§0.5 + SA-S5-7)**: flow
  `persistence_restart.yaml` đã viết xong (seed 42,
  thứ tự khay [3, 4, 8, 0, 2, 1, 5, 6, 7], hình học
  Đ7 1080×2340, long-press = swipe tại chỗ 600ms
  rồi drag) và bàn giao — **chưa chạy kiểm chứng
  tại máy James** (VM không có emulator/APK build);
  lần chạy thật đầu tiên là việc local/schedule của
  Paul/Claude, CI Maestro là việc hạ tầng riêng.
- **Binary chờ upload web UI** (connector không đẩy
  được): `content/packs/animals/1/a1p1/play.webp`
  (sha256 `3348d0a0…`) và `thumb.webp` (`72e97b36…`)
  lên nhánh `feat/S1-05-completion` — bản copy +
  nguồn CC0 ở `~/workspace/puzze-game/content-upload/`
  (SOURCE.md). Chỉ nhánh feat cần; CI job content
  chỉ cần manifest.json (text, đã đẩy qua connector).

## 2026-11-28 — S1-05: mở contract (James)

- `harness/contracts/S1-05.md`: ghi 8 chốt của
  Opus (comment `7235735330`, SA-S5-1..SA-S5-8,
  chốt theo khuyến nghị ở cổng `7235640949`) —
  content thật tối thiểu `a1p1` (The Met 435703,
  "Weaning the Calves", Rosa Bonheur 1879, CC0) +
  pubspec `- content/`; seed `GAME_SEED` cho
  Maestro; `CompletionScreen` push sau
  `markSolved`; `onCompleted(Duration)` +
  Stopwatch + cập nhật WID-JP-10; một `ProgressDao`
  dùng chung trong app shell; nhãn `<n> solved` +
  WID-TS-01b; Maestro chỉ bàn giao flow; test
  WID-CP-01..06 + INT-CS-01..03. Ba điều chỉnh chữ
  ghi rõ trong contract: `asset.title` thay
  `asset.name` trong phác SA-S5-5, khóa asset
  `'content/' + playPath` (S1-01 §4), nhãn thẻ giữ
  hậu tố `, locked` của SA-UI-7 sau phần solved.
- Cùng PR: khối pre-check `S1-05` trong
  `tool/check_e_step.sh` + thêm vào `precheck_s1`
  của `tool/evaluate.sh`.
- Kiểm chứng tại máy: pre-check S1-05 fail đúng lý
  do đầu tiên (`test/features/completion/` chưa
  có); S1-01..04 vẫn OK.

## 2026-11-28 — S1-04: test đã khóa, màn chơi đã code (James)

- PR `test/S1-04`: `jigsaw_play_test.dart`
  (WID-JP-01..12, hash `4928558f…`),
  `integration_test/jigsaw_snap_test.dart`
  (IT-J-01..04, `33bf0cd4…`) +
  `completion_event_test.dart` (IT-J-05..06,
  `59601599…`), `board_test.dart` thêm ENG-J-54
  (`d5c216aa…`) — tất cả khóa vào
  `harness/tests.lock`. Ảnh test sinh tất định bằng
  PictureRecorder + MemoryImage, không PNG fixture.
- Nhánh `feat/S1-04-jigsaw-play`:
  `lib/features/jigsaw_play/` (một `Listener` toàn
  bảng + máy trạng thái kéo: long-press từ khay,
  kéo trực tiếp trong bảng, pointer thứ hai bị bỏ
  qua; `JigsawBoardPainter` vẽ từ MỘT `ui.Image`
  bằng drawImageRect; Preview overlay 0.7 bằng
  Listener thô — GestureDetector.onTapDown chỉ bắn
  sau khi arena phân xử nên không dùng; Hint viền
  vàng 1,2 giây bằng Timer; `onCompleted` đúng một
  lần qua `PlaceResult.justCompleted` rồi khóa
  kéo), `lib/app.dart` (MaterialApp + ThemeSelect
  nối dây: asset (theme, level 1) đầu tiên →
  JigsawPlayScreen với ResizeImage, không có →
  JigsawEmptyScreen; tolerance đọc từ
  config/game_config.json với `cache: false` —
  future cache của rootBundle treo khi sang test
  khác, đã kiểm chứng) + `lib/main.dart` chỉ còn
  runApp, trần gridSize 64 trong `Board.square`,
  pubspec khai báo asset config.
- **Khay cuộn ngang** (làm rõ §8 của contract,
  commit bổ sung trên PR contract): 9 ô × cạnh ô
  ≈ 1080dp > màn hình nên khay là dải cuộn ngang
  đúng §6; kéo ngang trong khay trước long-press
  thì thành cuộn. Test cuộn ô đích vào giữa khay
  trước mỗi lần kéo.
- Kiểm chứng tại máy: `evaluate.sh S1` PASS mọi
  cổng trừ integration — pre-check S1-01..04 OK,
  purity PASS, tests lock PASS, analyze PASS,
  **186/186 test** (173 cũ + WID-JP-01..12 +
  ENG-J-54), engine coverage **92,4%**. Cổng
  integration fail tại máy chỉ vì môi trường
  ("No supported devices connected" — VM không có
  emulator, project không có platform desktop);
  theo Đ11 integration là cổng CI `android-it`,
  kết quả chờ CI của chồng. Diff `test/` +
  `integration_test/` + tests.lock giữa nhánh test
  và feat: rỗng.

## 2026-11-28 — S1-04: mở contract (James)

- `harness/contracts/S1-04.md`: ghi 11 chốt của
  Opus (comment `7233002927`, chốt 11/11 theo
  khuyến nghị ở cổng `7232943144`) — ảnh tiêm qua
  constructor + fixture sinh bằng PictureRecorder,
  Preview overlay 0.7 + Hint viền vàng 1,2 giây,
  `onCompleted` đúng một lần rồi khóa kéo (không
  DB/màn kết thúc — S1-05), app shell `lib/app.dart`
  + `main.dart` rút gọn, constructor chốt nguyên,
  ba phản ứng theo PlaceResult, công thức hình học
  (boardTop 56, trayHeight 112), long-press từ khay,
  trần gridSize 64 + ENG-J-54, Test ID WID-JP/IT-J
  và integration là cổng CI android-it (không phải
  cổng local).
- Hai điểm suy ra ghi rõ trong contract chờ Opus
  xác nhận: overlay Preview dùng `Image` với
  provider đã tiêm (constructor không giữ bytes nên
  không dùng `Image.memory` như câu chữ Đ2) và
  `AssetLoader` chưa có `firstAsset` nên `app.dart`
  tự chọn bản ghi (theme, level 1) đầu tiên từ
  `load()`; ô khay giữ vị trí theo toàn bộ hoán vị
  TrayOrder (luật E3).
- Cùng PR: khối pre-check `S1-04` trong
  `tool/check_e_step.sh` (ba họ ID WID-JP / IT-J /
  ENG-J) + `tool/evaluate.sh` chạy thêm khối này
  trong `precheck_s1`.
- Kiểm chứng tại máy: pre-check S1-04 fail đúng lý
  do đầu tiên ở giai đoạn contract
  (`lib/features/jigsaw_play/` chưa có); S1-01 +
  S1-02 + S1-03 vẫn OK.

## 2026-11-28 — S1-03: test đã khóa, ThemeSelect đã code (James)

- PR `test/S1-03`: `theme_select_test.dart` +
  `theme_view_model_test.dart` (WID-TS-01..15), khóa
  hash vào `harness/tests.lock` (test `b4d99a71…`,
  unit `0062190e…`, golden PNG `4f435443…` — PNG
  sinh tại máy local bằng `--update-goldens`, chờ
  Paul/Claude bổ sung vào nhánh test qua web UI vì
  connector không đẩy được binary, SA-UI-5).
- Nhánh `feat/S1-03-theme-select`:
  `lib/features/theme_select/theme_progress.dart`
  (catalog cố định SA-UI-2, `ThemeViewModel`,
  `ThemeProgressProvider`, `computeThemeViewModel`
  — solvedCount là hợp hai mode theo luật E5,
  totalOwned = puzzleCount tới S3,
  `AssetThemeProgressProvider`) +
  `theme_select_screen.dart` (5 thẻ, badge khóa
  overlay, Semantics theo SA-UI-7, callback
  `onThemeSelected`, không đụng main.dart). Thẻ dùng
  một node Semantics duy nhất mang cả nhãn + hành
  động chạm (GestureDetector loại khỏi semantics) —
  InkWell tự tạo node chạm không nhãn khiến
  labeledTapTargetGuideline fail, đã kiểm chứng.
- Kiểm chứng tại máy: `evaluate.sh S1` XANH TOÀN
  BỘ — pre-check S1-01/S1-02/S1-03 OK, purity PASS,
  tests lock PASS, analyze PASS, **173/173 test**
  (158 cũ + WID-TS-01..15, gồm golden pass trên
  Linux), engine coverage 92,4%.
- Ghi chú chồng: PR contract #35 có thêm 1 commit
  fix (doc-comment chứa dấu `<>` làm analyze fail
  `unintended_html_in_doc_comment` trong
  `test/flutter_test_config.dart` + refresh hash
  trong tests.lock) — sửa trên PR contract còn
  draft, theo tiền lệ S1-02.

## 2026-11-28 — S1-03: mở contract (James)

- `harness/contracts/S1-03.md`: ghi nguyên 7 chốt
  SA-UI-1..7 của Opus (comment `7231445982`) — 5 thẻ
  chủ đề, khóa = cổng cấp tiếp theo qua gate.dart,
  catalog cố định theo schema enum, provider tiêm
  interface + `computeThemeViewModel`, không đụng
  main.dart, golden phương án (a) với font Roboto từ
  SDK, Test ID `WID-TS-01..15`.
- Cùng PR: khối pre-check `S1-03` trong
  `tool/check_e_step.sh` + `tool/evaluate.sh` chạy
  thêm khối này; `test/flutter_test_config.dart` nạp
  Roboto từ Flutter SDK cho golden (SA-UI-5); thư
  mục `test/goldens/` với file giữ chỗ `.gitkeep`
  (PNG sinh ở bước test, lên nhánh test qua web UI
  vì connector không đẩy được binary). Hai file hỗ
  trợ test tạo ở bước này đã khóa hash vào
  `harness/tests.lock`.
- Kiểm chứng tại máy: pre-check S1-03 fail đúng lý
  do đầu tiên ở giai đoạn contract
  (`lib/features/theme_select/` chưa có); S1-01 +
  S1-02 vẫn OK.

## 2026-11-28 — S1-02: PR #31 đã merge — chồng đã rebase lên main mới, feat đã push + mở PR (James)

- PR `test/S1-02`: `app_database_test.dart`
  (UNIT-DB-01..16), khóa hash vào `harness/tests.lock`
  (hash cuối `7390897e…` sau khi gõ
  `Map<String, dynamic>` ở UNIT-DB-16 cho
  strict_raw_types).
- Nhánh `feat/S1-02-drift-dao`: `lib/data/app_database.dart` (bảng Progress
  PK (image_id, mode) + Settings key–value,
  schemaVersion 1, `AppDatabase.production()` qua
  drift_flutter) + `lib/data/progress_dao.dart`
  (ProgressModes + ProgressDao: markSolved upsert,
  isSolved, solvedIds, get/setSetting) + file `.g.dart`
  sinh bằng build_runner --force-jit +
  `drift_schemas/drift_schema_v1.json`. Gói nâng nền:
  `.fvmrc` 3.50.1, `drift_dev: ^2.35.3` trong pubspec,
  lock sinh lại trên SDK 3.50.1, analysis_options nhận
  bản exclude tool tự nâng cấp + dòng suppress
  `deprecated_member_use: ignore`.
- Điều chỉnh SA-DB-7 theo verdict CI của PR #31
  (comment 7229591289): BỎ mục đổi import
  `lib/main.dart` — material_ui không có trong
  pubspec nên import đó làm analyzer nổ; giữ
  material.dart + suppress deprecation trong
  analysis_options (Hướng B của phòng).
- PR #31 đã merge vào main (commit `8bb45251`,
  comment 7231057960, CI 4/4 xanh): ci.yml 3.50.1,
  suppress có sẵn trên main, Gradle 9.5.0 / AGP
  9.3.1 / Kotlin 2.4.20. Cả chồng S1-02 đã rebase
  lên main mới (xung đột duy nhất ở
  analysis_options.yaml — bản feat thắng vì là
  superset: giữ nguyên suppress của main + comment
  giải thích + exclude của tool; feat không đụng
  android/, lib/main.dart, .github/).
- Kiểm chứng tại máy SAU rebase:
  `bash tool/evaluate.sh S1` XANH TOÀN BỘ —
  pre-check S1-01 + S1-02 OK, purity PASS, tests
  lock PASS, analyze PASS, **158/158 test pass**
  (142 test cũ + UNIT-DB-01..16), engine coverage
  92,4% (365/395). `bash tool/evaluate.sh E6` cũng
  XANH TOÀN BỘ — không hồi quy cổng cũ. Hash
  app_database_test.dart sau rebase không đổi:
  `7390897e…`.
- Diff `test/` + `harness/tests.lock` giữa
  `test/S1-02` và nhánh feat sau rebase: rỗng.
- Còn treo: chờ Opus duyệt cả chồng S1-02 (gồm 2
  điểm suy ra trong contract: luật null best_time
  §5.1; solvedIds tăng dần + settings trong
  ProgressDao §5.2) → Claude merge.

## 2026-11-28 — S1-02: mở contract lưu tiến độ drift (James)

- S1-02 (lưu tiến độ bằng drift): James dừng ở cổng
  contract (comment 7228829524); Paul chốt Hướng B —
  nâng Flutter lên 3.50.1 thay vì hạ drift (comment
  7228865069); James kiểm chứng Hướng B đầu-cuối tại
  máy (comment 7229079307: drift_dev 2.35.3 resolve
  sạch trên SDK mới, 142/142 test pass, analyze chỉ đỏ
  1 dòng deprecation ở lib/main.dart). Opus chốt
  SA-DB-1..7 (comment 7229335986): PK (image_id, mode)
  + best_time nullable int giây; mode hằng chuỗi
  'jigsaw'/'word' trong file DAO; settings key–value;
  markSolved upsert giữ solved_at lần đầu + best_time
  = min; production mở qua drift_flutter
  (game_puzzle.sqlite), test qua NativeDatabase file;
  schemaVersion = 1 + dump schema tại S1-02 + Test ID
  UNIT-DB-01..; đổi import material.dart →
  material_ui trong feat PR.
- PR docs/s1-02-contract (PR này): contract S1-02 +
  mở rộng pre-check S1-02 trong tool/check_e_step.sh +
  khối S1 trong tool/evaluate.sh chạy thêm S1-02, và
  dòng progress này.
- Cổng cứng: 3 chỗ flutter-version trong
  .github/workflows/ci.yml phải sửa qua GitHub web UI
  (3.38.1 → 3.50.1) TRƯỚC khi push nhánh feat của
  chồng S1-02; contract + test PR mở bình thường ngay.
- Còn treo: chờ Opus duyệt contract → James viết test
  UNIT-DB-01..16 (PR test/S1-02) → code feat; hai điểm
  suy ra chờ Opus xác nhận khi soát (luật null của
  best_time §5.1, thứ tự solvedIds + settings nằm
  trong ProgressDao §5.2).

## 2026-11-28 — S1-01: test đã khóa, AssetLoader đã code (James)

- PR `test/S1-01`: `asset_loader_test.dart` (UNIT-AL-01..12)
  + fixture `test/fixtures/manifest_valid.json` (3 bản ghi
  giả), khóa hash vào `harness/tests.lock` (test
  `4f94d139…`, fixture `f90b8fe2…`).
- PR `feat/S1-01-asset-loader` (PR này):
  `lib/services/asset_loader.dart` — `PuzzleAsset` bất biến
  9 trường + `AssetLoader` (hàm đọc tiêm qua constructor,
  mặc định `rootBundle.loadString`), kiểm cấu trúc theo
  contract §5, `FormatException` ở bản ghi hỏng đầu tiên,
  đường play/thumb suy ra theo quy ước cây §1.
- Kiểm chứng tại máy: `bash tool/evaluate.sh S1` XANH TOÀN
  BỘ — pre-check S1-01 OK, purity PASS, tests lock PASS,
  analyze PASS, **142/142 test pass** (130 test cũ +
  UNIT-AL-01..12), engine coverage 92,4% (365/395).
  `bash tool/evaluate.sh E6` cũng XANH TOÀN BỘ — cổng mở
  rộng không làm hồi quy các nhánh E.
- Diff `test/` + `harness/tests.lock` giữa `test/S1-01` và
  nhánh feat: rỗng (local + remote).
- Còn treo: chờ Opus duyệt cả chồng S1-01 → Claude merge;
  hai việc pipeline ở contract §8 (validator nới nhận danh
  sách, sửa mẫu image_id trong schema) làm bằng PR riêng.

## 2026-11-28 — S1-01: mở contract nạp nội dung (James)

- S1-01 (AssetLoader): James dừng ở cổng contract, Opus chốt
  6/6 điểm SA-1..SA-6 theo khuyến nghị của James (comment
  7227884824) — một file `content/manifest.json` chứa danh
  sách bản ghi, image_id `<theme>_<level>_<nn>`, loader chỉ
  kiểm cấu trúc trong Dart + `FormatException` ở bản ghi
  hỏng đầu tiên, class `AssetLoader` với hàm đọc tiêm qua
  constructor (mặc định `rootBundle.loadString`) trả
  `List<PuzzleAsset>`, chưa đưa `en_alt` (điểm hẹn chuyển
  sang contract S2-01), Test ID `UNIT-AL-01..12`.
- PR docs/s1-01-contract (PR này): contract S1-01 + mở rộng
  pre-check S1-01 trong `tool/check_e_step.sh` + nhánh `S1`
  trong `tool/evaluate.sh` (SA-6) + việc phụ Opus giao: nhãn
  Android `game_puzzle` → `Game Puzzle` trong
  AndroidManifest.
- Chưa có hình duyệt nào (`content/` chưa tồn tại) nên
  S1-01 dùng manifest giả trong `test/fixtures/` theo đúng
  chữ MUSE_STEPS. Hai việc pipeline (validator nới nhận
  danh sách; sửa mẫu image_id trong schema) ghi trong
  contract §8 — việc riêng, không chặn S1-01.
- Còn treo: chờ Opus duyệt contract → viết test UNIT-AL
  khóa hash → code `lib/services/asset_loader.dart`.

## 2026-11-28 — E6: test đã khóa, engine random picker đã code (James)

- PR `test/E6`: `random_picker_test.dart` (ENG-R-01..15), khóa
  hash vào tests.lock (404b728e… — đã gồm dart format trước khi
  khóa). PR `feat/E6-random` xếp chồng:
  `lib/engine/content_mode/random_picker.dart` — hàm thuần
  top-level `pick(pool, recentlySolved, k, rng)`, K_eff =
  min(K, pool.length − 1), cửa sổ đếm trên các phần tử gần nhất
  thuộc pool (ngoài pool / trùng không chiếm suất), một lần
  `nextInt` trên eligible giữ thứ tự pool, pool rỗng → null,
  k < 0 / pool trùng → ArgumentError. Chỉ import dart:math.
- Kiểm chứng tại máy: `bash tool/evaluate.sh E6` XANH TOÀN BỘ —
  pre-checks, purity, tests lock, analyze PASS; 130/130 test
  (ENG-J-01..53 + ENG-W-01..35 + ENG-P-01..27 + ENG-R-01..15);
  engine coverage 92,4%.
- Theo cách merge của E1–E5: không merge PR #24/#25 riêng; cả
  chồng #24 + #25 + feat/E6-random squash một lần vào main khi
  Opus OK.

## 2026-11-28 — E5 đã merge; mở contract E6 (James)

- PR #23 (feat/E5-progress) đã squash merge vào main (commit
  f746bbe), CI 4/4 xanh, Opus OK toàn chồng #21/#22/#23; PR
  #21/#22 đã đóng "bao hàm trong #23". Engine cổng 75%
  (ENG-P-01..27) chính thức ở trên main — 115/115 test, engine
  coverage 92,0%.
- E6 (Random): James dừng ở cổng contract, Opus chốt 7/7 điểm
  theo khuyến nghị của James (comment 7226957118) — hàm thuần
  top-level `pick(pool, recentlySolved, k, rng)`, pool là
  `List<String>` image_id, K = 10 chính thức với
  K_eff = min(K, pool.length − 1), pool rỗng → null, một lần
  `nextInt` trên eligible giữ thứ tự pool, chỉ
  `random_picker.dart` (không curated.dart), test ENG-R-01..15.
- PR docs/e6-contract (PR này): contract E6 + mapping `E6)`
  subdir="content_mode" trong tool/check_e_step.sh + việc phụ
  Claude giao ở comment merge E5: sửa cây §1 trong
  harness/MUSE_STEPS.md (progression/unlock_rule.dart →
  progress/gate.dart).

## 2026-11-27 — E5: test đã khóa, engine cổng 75% đã code (James)

- PR `test/E5`: `gate_test.dart` (ENG-P-01..27), khóa hash vào
  tests.lock (42187255… — đã gồm dart format trước khi khóa).
  PR `feat/E5-progress` xếp chồng: `lib/engine/progress/gate.dart`
  — hai hàm top-level thuần `isUnlocked` / `requiredSolved`,
  ngữ nghĩa normative `requiredSolved(n, t) = floor(t × n) + 1`,
  validation đúng mẫu Opus (threshold thuộc (0, 1] và hữu hạn;
  totalOwned = 0 → khóa / required 1; đầu vào âm, solved > total
  → ArgumentError). Không import, không trạng thái.
- Kiểm chứng tại máy: `bash tool/evaluate.sh E5` XANH TOÀN BỘ —
  pre-checks, purity, tests lock, analyze PASS; 115/115 test
  (ENG-J-01..53 + ENG-W-01..35 + ENG-P-01..27); engine coverage
  92,0%.
- Theo cách merge của E1–E4: không merge PR #21/#22 riêng; cả
  chồng #21 + #22 + feat/E5-progress squash một lần vào main khi
  Opus OK. Điểm lệch đường dẫn (progress/gate.dart thay vì
  progression/unlock_rule.dart ở cây §1) chờ Opus xác nhận khi
  soát.

## 2026-11-27 — E4 đã merge; mở contract E5 (James)

- PR #20 (feat/E4-word) đã squash merge vào main (commit
  ab1e933), CI 4/4 xanh, Opus OK toàn chồng #18/#19/#20; PR
  #18/#19 đã đóng "bao hàm trong #20". Engine ghép chữ
  (ENG-W-01..35) chính thức ở trên main.
- James dừng một nhịp ở cổng contract E5 (comment 7217927650):
  luật cổng 75% đã chốt hết, còn năm điểm kiến trúc chưa chốt.
  Opus đã chốt cả năm, theo James cả năm (comment 7218341139):
  (1) hai hàm top-level thuần `isUnlocked` / `requiredSolved`
  trong `lib/engine/progress/gate.dart`; (2) ngữ nghĩa normative
  `requiredSolved(n, t) = floor(t × n) + 1`, `isUnlocked` định
  nghĩa qua nó, test chỉ ghim threshold nhị phân chính xác;
  (3) ca biên: totalOwned = 0 → khóa (false) / required = 1,
  đầu vào âm, solved > total, threshold ngoài (0, 1] hoặc
  NaN/∞ → ArgumentError; (4) Test ID ENG-P-01..; (5) engine chỉ
  nhận ba con số đã tổng hợp, lọc mode/owned/free-tier là việc
  tầng gọi.
- Điểm lệch đường dẫn ghi rõ trong contract E5: cây MUSE_STEPS
  §1 ghi `lib/engine/progression/unlock_rule.dart`, Opus chốt
  `lib/engine/progress/gate.dart` — theo Opus, chờ Opus xác
  nhận khi soát (James không tự sửa MUSE_STEPS).
- Mở PR `docs/e5-contract`: contract E5 (test ENG-P-01..27) kèm
  mapping `E5)` trong `tool/check_e_step.sh`.

## 2026-11-27 — E4: test đã khóa, engine ghép chữ đã code (James)

- PR `test/E4`: `sentence_test.dart` (ENG-W-01..11 + ENG-W-29..35)
  và `validator_test.dart` (ENG-W-12..28), khóa hash vào tests.lock
  (5d2ef2d5… / 6a837212… — đã gồm dart format trước khi khóa). Giá
  trị ghim shuffle/scramble (ENG-W-09/10/26) là đầu ra Fisher–Yates
  theo contract chạy với Random(seed) của Dart VM. PR
  `feat/E4-word` xếp chồng: `lib/engine/word/sentence.dart`
  (WordToken/Sentence token = từ, mảnh chỉ-dấu-câu gộp trước/sau,
  WordBoard bất biến + lệnh PickToken/ReturnToken, lỗi chia
  ArgumentError/StateError như PlacePiece) và
  `lib/engine/word/validator.dart` (AnswerValidator so theo khóa
  chuẩn hóa, kiểm multiset khi tạo, scramble không trùng đáp án,
  canScramble theo đếm dãy khóa phân biệt).
- Kiểm chứng tại máy: `bash tool/evaluate.sh E4` XANH TOÀN BỘ —
  pre-checks, purity, tests lock, analyze PASS; 88/88 test
  (ENG-J-01..53 + ENG-W-01..35); engine coverage 91,6%.
- Theo cách merge của E1–E3: không merge PR #18/#19 riêng; cả
  chồng #18 + #19 + feat/E4-word squash một lần vào main khi Opus
  OK.

## 2026-11-27 — E3 đã merge; mở contract E4 (James)

- PR #17 (feat/E3-place-piece) đã squash merge vào main (commit
  aca0e21), CI 4/4 xanh, Opus APPROVED toàn chồng #15/#16/#17 và
  chấp nhận hai điểm lệch đã ghi trong contract E3 §6; PR #15/#16
  đã đóng "bao hàm trong #17". Engine PlacePiece + TrayOrder
  (ENG-J-30..53) chính thức ở trên main.
- James dừng một nhịp ở cổng contract E4 (comment 7217272660):
  MUSE_STEPS §E4 chỉ có hai dòng, năm quyết định kiến trúc chưa
  chốt. Opus đã chốt cả năm (comment 7217451924): (1) token = TỪ,
  dấu câu dính, mảnh chỉ-dấu-câu gộp vào token trước/sau, giữ
  Sentence.fromTokens cho cụm; (2) đáp án do caller cấp dạng
  List<String>, câu gốc là đáp án số 0, schema en_alt để S1;
  (3) so sánh theo khóa chuẩn hóa (bỏ dấu hai đầu + toLowerCase,
  giữ dấu giữa từ), validator kiểm multiset ngay khi tạo;
  (4) scramble Fisher–Yates bắt buộc không trùng đáp án, tối đa
  maxAttempts trên cùng Random, canScramble == false thì trả lần
  xáo cuối; (5) Test ID ENG-W-01.. — James đã kiểm regex hai cổng
  trước khi viết: check_e_step trích ID bằng mẫu tổng quát,
  verify_tests_lock không có regex ID, nên không cần mở regex.
- Mở PR `docs/e4-contract`: contract E4 (test ENG-W-01..35) kèm
  mapping `E4)` trong `tool/check_e_step.sh`.

## 2026-11-27 — E3: test đã khóa, engine PlacePiece + TrayOrder đã code (James)

- PR `test/E3`: `place_piece_test.dart` (ENG-J-30..43 + ENG-J-53)
  và `tray_order_test.dart` (ENG-J-44..52), khóa hash vào tests.lock
  (d7ba3df3… / c7d2f4f4… — đã gồm dart format trước khi khóa). PR `feat/E3-place-piece` xếp chồng:
  `lib/engine/jigsaw/commands.dart` (PlacePiece/PlaceResult đồng bộ,
  ô bận → rejectedOccupied không đổi bàn, moved kiểm ô đích trước)
  và `lib/engine/jigsaw/tray_order.dart` (hoán vị cố định, fromList
  kiểm hoán vị, visible lọc qua hàm isPlaced của tầng trên).
- Theo cách merge của E1/E2: không merge PR #15/#16 riêng; cả chồng
  #15 + #16 + feat/E3-place-piece squash một lần vào main khi
  evaluate E3 xanh và Opus OK.

## 2026-11-27 — E2 đã merge; mở contract E3 (James)

- PR #14 (feat/E2-snap) đã squash merge vào main (commit a7b1ec),
  CI 4/4 xanh, Opus OK toàn chồng #12/#13/#14; PR #12/#13 đã đóng
  "bao hàm trong #14". Engine snapTarget (ENG-J-18..29) chính thức
  ở trên main.
- James dừng một nhịp ở cổng contract E3 (comment 7216515521):
  MUSE_STEPS §E3 chỉ có hai dòng, ba quyết định kiến trúc chưa chốt.
  Opus đã chốt cả ba (comment 7216649316): (1) ô bận → từ chối
  `rejectedOccupied` kèm occupantId, luật phụ moved/noop; (2)
  PlacePiece là class lệnh bất biến trong commands.dart, đồng bộ,
  justCompleted tính trong apply, fromMap không phát sự kiện;
  (3) TrayOrder giữ hoán vị cố định của mọi id, lưu ghi hoán vị
  không ghi seed, số Semantics = indexOf + 1.
- Mở PR `docs/e3-contract`: contract E3 (test ENG-J-30..53, ghi kèm
  ID Opus E3-P/C/T — dãy ENG-J giữ nguyên vì cổng check_e_step trích
  ID theo mẫu ENG-J), kèm mapping `E3)` trong `tool/check_e_step.sh`.
  Hai điểm lệch có ghi rõ trong contract §6 chờ Opus xác nhận:
  E3-C06 "bàn 1×1" không dựng được vì E1 chốt gridSize ≥ 2, nên
  ENG-J-42 kiểm ca biên tương đương 2×2; và E3-C03 "moved hoàn
  thành bàn" bất khả về mặt toán học theo luật mỗi ô một mảnh của
  E1, nên ENG-J-39 kiểm biên gần nhất tới được.

## 2026-11-27 — E2: test đã khóa, engine snap đã code (James)

- Contract E2 (PR #12) được Opus OK có điều kiện; James đã sửa cả ba
  mục trong PR #12 (dung sai phải hữu hạn + ENG-J-24 thêm NaN/±∞;
  điểm thả là tâm mảnh + luồng E3 và snap vẫn trả ô bận trong
  ENG-J-27; hòa ở dung sai ≥ 0.5 và dòng cấm import flutter/dart:ui).
- PR `test/E2`: `snap_test.dart` ENG-J-18..29, khóa hash vào
  tests.lock (eb9d5b5f…). PR `feat/E2-snap` xếp chồng: thêm
  `Board.snapTarget` (Euclid tới tâm gần nhất, biên bao gồm, hòa chọn
  row/col nhỏ hơn, thuần túy không đổi trạng thái).
- Theo cách merge Opus khuyến nghị: không merge PR #12 riêng (CI sẽ
  đỏ vì contract chưa có test); cả chồng #12 + test/E2 + feat/E2-snap
  squash một lần vào main khi evaluate E2 xanh.

## 2026-11-27 — E1 đã merge; mở contract E2 (James)

- PR #11 (feat/E1-board) đã squash merge vào main (commit f0850ae),
  CI 4/4 xanh, Opus OK. **PR #10 (test/E1) đã đóng — nội dung đã bao
  hàm trong PR #11** (theo yêu cầu ghi chép của Claude sau merge).
  Engine Board/piece (ENG-J-01..17) chính thức ở trên main.
- Mở PR `docs/e2-contract`: contract E2 (hút mảnh + dung sai, test
  ENG-J-18..29), kèm mapping `E2)` trong `tool/check_e_step.sh` và
  ghi chú `placed: null` trong quyết định 10 của contract E1.
- Các mục không chặn còn gom lại cho bước sau: trần trên cho
  `gridSize` (làm khi viết contract S1), các ca purity còn lọt đã ghi
  ở PR #9.

## 2026-11-27 — Phase E1: engine Board đã code (James, nhánh feat/E1-board)

- PR #9 đã squash merge vào main (commit 7a149ae) sau khi Opus OK và
  CI 4/4 xanh. Chồng PR #10/#11 đã đồng bộ lên main mới 7a149ae: phía
  James rebase thật tại máy; hai nhánh remote được cập nhật bằng một
  commit đồng bộ cây (connector GitHub không force-push được) — cây
  của hai nhánh khớp bản rebase, đã đối chiếu từng file. (Đính chính
  câu cũ "PR #10 đã rebase lên main mới": bản rebase lúc đó mới có ở
  máy James, chưa lên remote — Opus bắt lỗi này khi soát PR #11.)
- `lib/engine/jigsaw/board.dart`: Board/piece thuần Dart theo contract
  E1 — gồm cả `toMap()`/`fromMap()` (quyết định 10) và hai test mới
  ENG-J-16 (bất biến, seed cố định) và ENG-J-17 (vòng đi-về) được thêm
  theo rà kiến trúc của Claude; tests.lock khóa lại (hash 60c7de3a… —
  ENG-J-17 được bổ sung theo Opus: ghim dạng xuất của toMap(), vòng
  đi-về qua JSON thật, các ca sai kiểu dữ liệu và khóa không chuẩn).
- **Ghi chú cho E2 (theo Opus):** khi mở contract E2 phải thêm mapping
  `E2)` vào `tool/check_e_step.sh` trong cùng PR, nếu không CI đỏ.
- Các lọt purity nhỏ còn lại (Random tách dòng với ngoặc, `DateTime . now`)
  để PR sau theo Opus.

## 2026-11-27 — PR #8 vòng sửa 2 theo Opus review (James)

Opus: OK có điều kiện, chưa merge (C1/C3/C4/T4 đạt; C2/T1/T2/T3 đạt một
phần). Đã sửa trong PR #8:

- **Chặn merge — quy trình test-trước-code:** §4 mục 5 chốt cách (a) PR
  xếp chồng: test/E1 được duyệt + khóa hash nhưng không merge vào main
  một mình (main chưa có lib/engine sẽ đỏ); feat/E1-board dựng chồng
  trên test/E1, cả hai xanh mới merge vào main. Cách (b) khung API ném
  UnimplementedError đã cân nhắc, không chọn.
- **ENG-J-10 viết chi tiết:** B ở Y đặt vào X đang có A → StateError;
  khẳng định pieceAt/positionOf/cả hai count không đổi sau lỗi; thêm ca
  B đang ở khay thì sau lỗi vẫn ở khay.
- **Ghi chú thiết kế mới (T3):** xáo khay chỉ đổi thứ tự hiển thị, không
  đổi id/ô nhà; khóa lưu trữ là (image_id, gridSize, pieceId); nhãn
  Semantics dùng số thứ tự trong khay, không dùng id (id lộ ô nhà).
- **ci.yml:** bước coverage thêm nhánh elif — có test/engine mà thiếu
  lib/engine thì FAIL.
- **Việc rẻ làm luôn:** ENG-J-14 liệt kê (−1,0), (0,3), (3,0) + khẳng
  định trạng thái không đổi; ENG-J-08/09/12 dùng số cụ thể trên bàn 3×3;
  gateThreshold — thresholds.yaml là nguồn duy nhất, config là bản sao,
  CI thêm bước kiểm hai giá trị bằng nhau (đã tự kiểm: 0.75 == 0.75);
  game_config.json format nhiều dòng, có newline cuối file.
- **Rủi ro ghi thêm vào E1.md:** deny list chỉ chặn Edit/Write —
  Generator vẫn sửa được tool/ qua Bash; người viết test và Generator
  đều là James, nên lớp chặn thật là tests.lock + người duyệt độc lập.
- Sau vòng này PR #8 chuyển từ draft sang ready theo yêu cầu của Opus.

## 2026-11-27 — PR #9 vòng sửa 5 theo Opus soát lại (James)

- **Bắt buộc:** nội suy chuỗi `${...}` là code thật — strip_comments.awk
  nay chuyển sang trạng thái code trong `${...}` (đếm độ sâu ngoặc, hỗ
  trợ chuỗi lồng nhau) nên `'${DateTime.now()}'` không còn lọt cổng
  purity. Viết lại strip_comments.awk thành máy trạng thái có ngăn xếp
  ngữ cảnh.
- Raw string (`r'...'`) được nhận diện đúng: không escape, không nội
  suy — hết ca `r'C:\'` nuốt mất dấu đóng chuỗi.
- check_e_step: mirror làm trắng nội dung chuỗi ba nháy (khai báo test
  nằm trong `'''...'''` không còn được tính); regex skip nhận cả
  `skip : true` có dấu cách.
- CI: bước E-step pre-checks FAIL khi test/engine tồn tại mà không có
  contract `E*.md` nào.

## 2026-11-27 — PR #9 vòng sửa 4 theo code-review của Claude (James)

- **Chặn merge (mục 1):** cổng pre-check tách thành script riêng
  `tool/check_e_step.sh`; evaluate.sh gọi script này; CI thêm bước
  "E-step pre-checks" vào job Static gates (chạy cho mọi contract E*
  khi test/engine tồn tại). Hết cảnh PR tự xóa test + tự cập nhật
  tests.lock mà CI vẫn xanh.
- **Mục 2:** strip comment nay có ý thức chuỗi (tool/strip_comments.awk
  dùng chung): chuỗi chứa `//` hay tên API cấm không còn làm sai cổng;
  nội dung chuỗi được làm trắng khi quét API cấm.
- **Mục 3:** directive nằm giữa dòng sau dấu `;` (ví dụ
  `library engine; import 'dart:io';`) nay cũng bị kiểm.
- **Mục 4:** khai báo test xuống dòng (`test(` cuối dòng, tên ở dòng
  kế) được nối dòng trước khi so khớp ID — hết FAIL oan.
- **Mục 5:** mô tả PR #9 đã cập nhật đúng số file; các mục vòng sửa
  trong file này giữ nguyên thứ tự thời gian, câu chữ đã rà lại.

## 2026-11-27 — PR #9 vòng sửa 3 theo Opus review (James)

- **Pre-check ID (lỗ chặn merge):** strip comment khỏi các file test
  trước khi tìm; khai báo test phải bắt đầu dòng; ID phải kết thúc ở
  ranh giới không-phải-số — `// test('ENG-J-15'…`, `/* test(… */`, chuỗi
  ký tự chứa test('… và `test('ENG-J-150'` đều không còn tính cho
  ENG-J-15.
- **Purity:** gom directive import/export/part qua nhiều dòng tới dấu
  `;` rồi mới lấy URI; `part '…'` nay được kiểm như import; cấm thêm
  `Random.new`.
- **evaluate.sh:** nhánh ánh xạ gói đổi thành `*)` để bước lạ (ví dụ Ex)
  cũng FAIL "chưa ánh xạ gói" thay vì lọt.
- **spec.md:** ghi đúng tên hiển thị của hai required check là
  "Static gates" và "Unit tests + coverage" (không phải static/unit).

## 2026-11-27 — PR #9 vòng sửa theo Opus review (James)

Opus tái hiện được 5 lỗ trong các cổng của PR #9; đã sửa hết trong PR này:

- **Purity 1 — import có điều kiện:** nay kiểm MỌI URI trong ngoặc kép trên
  dòng import/export (trước chỉ lấy chuỗi cuối).
- **Purity 2 — package URI chứa `..`:** `package:game_puzzle/engine/../…`
  bị chặn (kiểm từng đoạn đường dẫn).
- **Purity 3 — import tương đối trần:** `import 'piece.dart';` (không ./)
  được coi là tương đối và kiểm resolve như thường (trước bị chặn oan).
- **Purity 4 — API cấm:** khớp theo token trọn vẹn, có hay không có ()
  cũng tính (tear-off `DateTime.now`, `Random.secure`, `Stopwatch` đều
  bắt); strip comment trước khi quét nên comment nhắc tên API không bị
  chặn oan; `SeededRandom()` và `Random(seed)` hợp lệ vẫn qua.
- **Pre-check 5 — ID test:** chỉ tính khi ID xuất hiện dạng `test('<ID>`
  hoặc `testWidgets('<ID>` trong file `*_test.dart` (comment/.txt không
  tính). Bổ sung bắt skip dạng `@Skip(`, `markTestSkipped(`, `skip:` kèm
  lý do (trừ `skip: false`). Bước E* chưa có ánh xạ gói → FAIL rõ ràng
  thay vì bỏ qua thầm lặng. Ghi chú trong evaluate.sh: CI không chạy
  script này — cổng pre-check chỉ chạy khi Evaluator chạy tay.

Kiểm chứng: 14 ca probe purity + 9 ca probe pre-check của James đều
đúng kỳ vọng. (Đính chính 27/11: câu này trước đây ghi "kể cả các ca
Opus đã tái hiện" — chưa chính xác: Opus soát vòng sau vẫn tìm được ca
ID nằm trong comment còn lọt; đã sửa ở vòng sửa tiếp theo bên trên.)

## 2026-11-27 — T5+T6: siết evaluate.sh và check_engine_pure.sh (James)

Theo yêu cầu của Opus ở PR #8 (PR riêng, xong trước feat/E1-board):

- **T5 — evaluate.sh:** thêm cổng "E-step pre-checks" cho các bước E*:
  contract phải tồn tại; lib/engine/<gói của bước> phải tồn tại (E1 →
  jigsaw); test/engine phải tồn tại; cấm test bị skip; mọi test ID nêu
  trong contract phải xuất hiện dưới test/engine. Kiểm chứng trên cây
  stub: đủ ID → qua hết các cổng; xóa ENG-J-15 → FAIL nêu đúng ID.
- **T6 — check_engine_pure.sh:** import tương đối phải resolve vào bên
  trong lib/engine (chặn ../ thoát ra ngoài); cấm thêm
  DateTime.timestamp(), Random.secure(), Stopwatch(). Kiểm chứng: import
  nội bộ OK; import thoát ra ngoài FAIL; 3 API cấm đều bắt được.

## 2026-11-27 — PR #8 vòng sửa 1 theo Opus review (James)

Opus: OK có điều kiện, chưa merge. Đã sửa trong PR #8:

- **C1:** ENG-J-07 viết lại — ca "N²−1 đúng + 1 sai" là không thể (chỉ còn
  một ô trống, chính là ô nhà của mảnh cuối). Ca mới: N²−2 đúng + 2 mảnh
  cuối đổi chỗ → isComplete false; gỡ ra đặt lại đúng → true; cộng ca
  N²−1 đúng + mảnh cuối chưa đặt → false.
- **C2:** CI và evaluate.sh thống nhất luật từ Giai đoạn E: có
  lib/engine/** hoặc test/engine/** mà thiếu harness/tests.lock hoặc
  thiếu coverage thì FAIL (sửa .github/workflows/ci.yml).
- **C3:** CODEOWNERS thêm /tool/, /.github/, /harness/contracts/;
  deny list của Generator thêm tool/** (contracts/** và .github/** đã có).
  Ghi rõ trong E1.md §4 mục 7.
- **C4:** E1.md ghi rõ vai trò: James viết contract + test (vai Contract),
  Claude/Opus duyệt PR test/E1 (khác Generator), Generator code sau khi
  test khóa. **Rủi ro ghi nhận: CODEOWNERS chỉ có một tài khoản
  (@yameshop95-png), tác giả không tự duyệt được PR của mình nên merge đi
  qua bypass của chủ repo; lớp chặn thật là tests.lock + CI + Opus review.**
- **T1:** thêm `int? pieceAt(CellPos)` vào API + ENG-J-15 (gồm ca đặt lại
  vào ô mình đang chiếm = no-op; chính sách thả vào ô bận ở tầng UI chốt
  ở E3). **T2:** ENG-J-14 ô ngoài lưới → ArgumentError. **T3:** ENG-J-02
  và ENG-J-13 khẳng định homeOf(id) == CellPos(id ~/ N, id % N).
  **T4:** K = 10 chỉ tạm thời; chốt ở E6 với K_eff = min(K, pool − 1).
- **T5+T6 để PR riêng, xong trước feat/E1-board:** evaluate.sh kiểm file
  test tồn tại/nằm trong lock/đủ ID/không skip + lib/engine/jigsaw/ tồn
  tại; check_engine_pure.sh bịt lỗ import tương đối ./ ../ thoát khỏi
  lib/engine và cấm thêm Random.secure(), DateTime.timestamp(), Stopwatch.

## 2026-11-27 — Giai đoạn E bắt đầu: contract E1 (James) — nhánh docs/e1-contract

- Viết `harness/contracts/E1.md` theo MUSE_STEPS §E1: mô hình Board/piece
  thuần Dart (lưới N×N từ config, id mảnh = chỉ số ô nhà, trạng thái
  đặt/chưa đặt), 13 test ENG-J-01..13, cổng nghiệm thu qua evaluate.sh.
  Chưa viết code engine, chưa viết test (test khóa hash qua PR test/E1 sau).
- Đề xuất `config/game_config.json`: gridSizes [3,4,6],
  snapToleranceRatio 0.2, gateThreshold 0.75, freePuzzlesPerTheme 2, và
  randomNoRepeatWindow 10 (K chưa chốt ở MUSE_STEPS — chờ Opus/Paul duyệt).
- Siết `tool/check_engine_pure.sh` theo yêu cầu review của Opus: danh sách
  import cho phép (chặn dart:ui, dart:io, package:flutter*, import ngoài
  lib/engine) + cấm DateTime.now() và Random() không seed. Đã kiểm chứng
  3 trường hợp: chưa có lib/engine → bỏ qua; file xấu → FAIL đúng dòng;
  file sạch → OK.
- Sửa câu về README ở mục 0.2 theo ghi nhận của Claude khi merge PR #7.
- Theo quy trình Paul chốt 27/11: PR này đăng lên issue #2, Claude/Opus
  kiểm tra, OK thì Claude tự merge.

## 2026-11-27 — Đổi tên puzze → puzzle (Paul chốt sau review PR #7)

"puzze" là lỗi chính tả — đổi toàn bộ sang **puzzle**: project `game_puzzle`,
applicationId `com.paperfox.game_puzzle`, bundle iOS `com.paperfox.gamePuzzle`,
nhãn hiển thị "Game Puzzle". Đổi được vì chưa publish; sau publish
applicationId khóa vĩnh viễn. Tên repo GitHub đổi sau (Settings → Rename,
link cũ tự chuyển hướng). flutter analyze sạch sau khi đổi.

## 2026-11-27 — Giai đoạn 0 (James, trong Muse) — nhánh chore/phase-0-repo-ci

- **0.1 XONG.** `git mv` toàn bộ pipeline vào `content_pipeline/`
  (validate_manifest.py, manifest.schema.json, CONTENT_PIPELINE.md, tests/).
  Kiểm chứng: `python3 -m pytest tests -q` trong content_pipeline → **25 passed**.
- **0.2 XONG (trừ build APK tại máy James — xem mục Treo).**
  `flutter create --org com.paperfox --platforms android,ios --project-name game_puzzle`
  trên Flutter 3.38.1 (ghim trong .fvmrc). applicationId `com.paperfox.game_puzzle`
  (org do Paul chốt: Paperfox — tên studio trung tính, vì org là công khai trên
  trang Play và không đổi được sau phát hành). README.md không bị flutter create đụng vào (diff rỗng tại thời điểm 0.2); tiêu đề của nó được đổi thành "Game-puzzle" ở commit đổi tên ngày 27/11/2026.
  Kiểm chứng: `flutter analyze` → **No issues found**; `flutter test` → **passed**.
- **0.3 XONG.** analysis_options.yaml: flutter_lints + strict-casts/inference/raw-types.
  Package: drift ^2.35.4, drift_flutter ^0.3.1, purchases_flutter ^11.0.6;
  dev: build_runner ^2.15.1, integration_test (SDK).
  **drift_dev hoãn có ghi lý do:** mọi bản drift_dev đi cặp với drift ≥ 2.34 đều đòi
  analyzer ^13, mà Flutter SDK 3.38.1 đã ghim không giải quyết được (solver fail cả
  ở cặp 2.34.5). Xét lại ở S1-02 khi cần sinh code lần đầu.
  Kiểm chứng sau khi thêm package: pub get OK, analyze sạch, test pass.
- **0.4 XONG.** tool/check_engine_pure.sh, tool/verify_tests_lock.sh,
  tool/check_coverage.dart, tool/evaluate.sh. evaluate.sh --dry-run in đúng thứ tự
  cổng: validator nội dung → engine purity → tests lock → analyze → test+coverage →
  coverage engine → integration test → (chỉ khi tất định pass) LLM chấm UX.
  verify_tests_lock và check_coverage **fail đúng mong đợi** ở giai đoạn này
  (chưa có tests.lock, chưa có lib/engine) — khóa test bắt đầu từ Giai đoạn E.
- **0.5 XONG.** .github/workflows/ci.yml: 4 job content / static / unit / android-it
  (emulator API 30 x86_64). Job static có bước **build APK debug** — chính là cổng
  kiểm chứng của 0.2 chạy trên CI. Các bước phụ thuộc Flutter/engine/tests.lock được
  bỏ qua có điều kiện cho tới khi phần tương ứng tồn tại. Maestro chạy local/theo lịch.
- **0.6 XONG.** harness/spec.md, thresholds.yaml (pass 8, tối đa 3 vòng FAIL,
  cùng lỗi 2 lần thì dừng, trần chi phí $300, cảnh báo ở $240), ux_rubric.md
  (4 mục, mô tả 4/6/8/10), progress.md, cost_ledger.csv.
- **0.7 PHẦN NGƯỜI.** .github/CODEOWNERS và .claude/settings.json lên main qua
  PR #3 (nhánh claude/eloquent-keller-gow6de); PR #4 và #5 là PR thử
  CODEOWNERS/ruleset (đã merge), PR #6 dọn các file thử đó. James đã review
  bản nháp ở issue #2: CODEOWNERS chỉ để @yameshop95-png (James không có login
  GitHub riêng). Ruleset "Protect main" ĐÃ bật sẵn, có bypass cho chủ repo
  (ghi nhận theo review của Claude trên issue #2 ngày 27/11, khớp lịch sử
  main). Cấu trúc cần nhớ: CODEOWNERS chỉ có một tài khoản và GitHub không
  cho tác giả tự duyệt PR của mình, nên merge thực tế đi qua bypass của chủ
  repo — lớp chặn thật là tests.lock chạy trong CI (đã ghi vào spec).
  drift_dev hoãn là CÓ CHỦ ĐÍCH (xem 0.3); **James chốt hướng xử lý trước
  S1-02**: nâng Flutter lên bản mới hơn, hoặc hạ drift về cặp phiên bản giải
  được cùng analyzer.

### Treo / giới hạn môi trường (minh bạch)

- **`flutter build apk --debug` chưa chạy được trên VM của James.** Đã truy tận gốc:
  (1) Java không qua được proxy egress của sandbox ở bước CONNECT (sdkmanager và
  Gradle wrapper cùng lỗi) — đã vòng bằng cách tải tay SDK/Gradle bằng curl và
  nạp chứng thư CA của proxy vào JDK; (2) sau đó Gradle vẫn fail "Could not receive
  a message from the daemon" — lớp giao tiếp tiến trình con (daemon) của Gradle/
  Kotlin không hoạt động trên VM này (gradle --version chạy, mọi build đều fail
  trong vài giây, kể cả --no-daemon vì Gradle 8 vẫn fork tiến trình con).
  Đây là giới hạn của môi trường James, **không phải lỗi của project**: bộ khung là
  template chuẩn của Flutter 3.38.1. Cổng này được kiểm chứng thay bằng bước
  build APK trong CI của chính PR này; Paul/Claude cũng build được trên máy thật.
- Vì proxy trên: hook native-assets của package sqlite3 (theo drift_flutter) không
  tự tải được libsqlite3 cho máy host — James đã nạp tay file .so chính hãng vào
  cache của hook để `flutter test` chạy. Trên máy thường và CI không cần bước này.
- iOS: chưa kiểm chứng build iOS (cần macOS — máy của Paul/Claude ở các mốc sau).

### Phụ lục CI (27/11/2026, sau khi viết mục trên)

- Lần chạy CI đầy đủ đầu tiên (run #8) fail ở `flutter analyze`: ci.yml chưa ghim
  phiên bản Flutter nên máy CI cài bản mới hơn nhiều (hậu 3.47), analyzer của nó
  báo lỗi deprecated trên chính file template của Flutter. Đã ghim
  flutter-version 3.38.1 khớp .fvmrc (commit 8357250).
- Run #9: analyze đạt, nhưng **build APK debug fail trong 17 giây** với thông
  điệp trần là "25.0.5.1" — log cho thấy cảnh báo restricted-method của JDK, chỉ
  xuất hiện trên JDK 24+, và 25.0.5.1 chính là phiên bản JVM mặc định của máy CI:
  Gradle 8.14 chỉ hỗ trợ chạy trên Java tới 24 nên chết ngay ở JDK 25. Đã ghim
  Temurin JDK 17 cho job static. Cùng run đó, job android-it fail vì khởi động
  emulator ~11 phút rồi timeout dù chưa có integration_test/ — đã sửa: chỉ cài
  Flutter và bật emulator khi thư mục integration_test/ tồn tại.
- **Run #10 (commit 9b23543): XANH TOÀN BỘ** — content 15s, static 4m53s (build
  APK debug đạt, 3m56s), unit 53s, android-it 10s (bỏ qua emulator đúng thiết
  kế). Cổng 0.2 như vậy đã được kiểm chứng trên CI. Cảnh báo Node 20 deprecated
  trên các action là nhiễu, không ảnh hưởng kết quả.
