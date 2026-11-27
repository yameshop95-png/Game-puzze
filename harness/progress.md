# Progress — nhật ký harness

Định dạng: ngày, giai đoạn, ai làm, đã xong gì, kiểm chứng bằng gì, còn treo gì.

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
