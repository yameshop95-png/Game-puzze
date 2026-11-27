# Progress — nhật ký harness

Định dạng: ngày, giai đoạn, ai làm, đã xong gì, kiểm chứng bằng gì, còn treo gì.

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
  trang Play và không đổi được sau phát hành). README.md không bị đụng (diff rỗng).
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
