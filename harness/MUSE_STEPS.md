# Hướng dẫn cho Muse: game-puzze (Flutter, Android trước, iOS sau)

Tài liệu do cố vấn Opus soạn, dựa trên các quyết định đã chốt trong issue #93 của repo Restaurant-app. Muse làm theo từng bước theo thứ tự. Mỗi bước kết thúc bằng một commit. Bước nào chưa "xong" thì chưa sang bước sau.

Bối cảnh đã chốt:
- Chỉ Android và iOS, app native. Không web, không PWA. Ngôn ngữ: chỉ tiếng Anh.
- Flutter (Dart). Lưu tiến độ: SQLite qua drift. Thanh toán: RevenueCat (`purchases_flutter`).
- Kiểm thử: `flutter test`, `integration_test` trên emulator Android, golden test, Maestro cho E2E. Không dùng Playwright.
- Harness chạy trên Muse.

---

## 1. Cấu trúc thư mục

```
game-puzze/
├─ README.md                      # giữ nguyên
├─ content_pipeline/              # chuyển nguyên nhóm, không sửa nội dung
│  ├─ validate_manifest.py  manifest.schema.json  CONTENT_PIPELINE.md
│  └─ tests/test_validate_manifest.py
├─ content/                       # chỉ chứa nội dung ĐÃ DUYỆT
│  ├─ manifest.json               # nguồn sự thật, validator chặn mặc định
│  └─ packs/<theme>/<level>/<image_id>/{play.webp, thumb.webp}
├─ config/game_config.json        # ngưỡng 0.75, dung sai hút, lưới, số hình miễn phí, cờ Random
├─ lib/
│  ├─ main.dart  app.dart
│  ├─ engine/                     # THUẦN DART: không import package:flutter
│  │  ├─ jigsaw/ (board.dart, piece.dart, snap.dart, commands.dart)
│  │  ├─ word/   (sentence.dart, validator.dart)        # nhiều thứ tự hợp lệ
│  │  ├─ progression/ (unlock_rule.dart)                # cổng 75%, chỉ tính nội dung đã sở hữu
│  │  └─ content_mode/ (curated.dart, random_picker.dart)  # có seed, không lặp
│  ├─ data/                       # drift: db.dart, tables/, dao/, migrations/
│  ├─ features/{home, theme_select, jigsaw_play, word_play, store, settings}/
│  ├─ services/                   # interface + impl: entitlement_service.dart
│  │                              # (RevenueCat & Fake), analytics_service.dart, asset_loader.dart
│  └─ ui/                         # theme, widget dùng chung, semantics helper
├─ test/
│  ├─ engine/   data/   features/   goldens/ (+ test/goldens/failures bị ignore)
│  └─ helpers/ (fake_entitlement.dart, test_db.dart)
├─ integration_test/ (jigsaw_snap_test.dart, perf_test.dart, ...)
├─ test_driver/perf_driver.dart
├─ .maestro/ (s1_vertical_slice.yaml, persistence_restart.yaml, ...)
├─ harness/
│  ├─ spec.md  progress.md  thresholds.yaml  ux_rubric.md  cost_ledger.csv
│  ├─ contracts/S1-01.md ...      # mỗi tiêu chí gắn test ID
│  └─ tests.lock                  # sha256 của mọi file test đã khóa
├─ tool/ (check_engine_pure.sh, check_coverage.dart, verify_tests_lock.sh, evaluate.sh)
└─ .github/{workflows/ci.yml, CODEOWNERS}
```

---

## 2. Các bước theo thứ tự

### Giai đoạn 0: Repo và CI

**0.1. Chuyển pipeline nội dung vào thư mục con**
- Đầu ra: `git mv validate_manifest.py manifest.schema.json CONTENT_PIPELINE.md tests content_pipeline/`, rồi xóa `__pycache__` và `.pytest_cache`.
- Kiểm chứng: `cd content_pipeline && python3 -m pytest tests -q` báo **25 passed**.
- Rủi ro: chỉ chuyển một phần file sẽ làm import hỏng. Không sửa file test để "cho chạy".

**0.2. Khởi tạo Flutter**
- Đầu ra: `flutter create --org <hỏi Paul> --platforms android,ios --project-name game_puzze .`. Ghi phiên bản Flutter vào `.fvmrc` hoặc vào một file phụ (không sửa README gốc).
- Kiểm chứng: `flutter analyze` báo 0 issue; `flutter test` pass; `flutter build apk --debug` thành công.
- Rủi ro: `flutter create .` có thể ghi đè README. Kiểm tra `git diff README.md` phải rỗng.

**0.3. Lint và các package**
- Đầu ra: `analysis_options.yaml` dùng `very_good_analysis` hoặc `flutter_lints`, thêm `strict-casts` và `strict-raw-types`. Thêm `drift`, `drift_flutter`, `purchases_flutter`, `integration_test`, `drift_dev`, `build_runner`. Khóa phiên bản bằng `pubspec.lock`.
- Kiểm chứng: `flutter pub get && flutter analyze` sạch.

**0.4. Script cổng kiểm tra**
- `tool/check_engine_pure.sh`: `grep -rn "package:flutter" lib/engine` phải rỗng.
- `tool/check_coverage.dart`: đọc `coverage/lcov.info`, lọc `lib/engine/`, đòi ≥ 80%.
- `tool/verify_tests_lock.sh`: so sha256 các file trong `test/ integration_test/ .maestro/ test_driver/` với `harness/tests.lock`.
- Kiểm chứng: chạy từng script. Script coverage phải fail khi chưa có test (đúng mong đợi).

**0.5. CI GitHub Actions** (`.github/workflows/ci.yml`)
- Job `content`: pytest và `python3 content_pipeline/validate_manifest.py content/manifest.json` (bỏ qua khi manifest chưa có).
- Job `static`: analyze, check_engine_pure, verify_tests_lock.
- Job `unit`: `flutter test --coverage`, check_coverage, golden (chỉ chạy trên ubuntu).
- Job `android-it`: `reactivecircus/android-emulator-runner`, API 30 x86_64, chạy `flutter test integration_test`.
- Maestro: chạy local hoặc theo lịch. Nếu CI không chạy được thì ghi rõ trong `progress.md`.
- Kiểm chứng: PR thử lên nhánh làm việc, mọi job xanh.
- Rủi ro: golden chạy trên macOS sẽ lệch font. Chỉ tạo và so golden trên Linux, dùng font đóng gói (load Roboto trong `flutter_test_config.dart`).

**0.6. Khung harness**
- Đầu ra: `harness/spec.md` (Planner viết), `thresholds.yaml` (pass_score 8, max_fail_rounds 3, same_error_stop 2, cost_cap_usd 300), `ux_rubric.md` (4 mục: độ sâu, chức năng, hình ảnh, chất lượng code; mỗi mục có mô tả điểm 4/6/8/10), `progress.md`, `cost_ledger.csv`.
- Kiểm chứng: `tool/evaluate.sh --dry-run` in đúng thứ tự các cổng. LLM chỉ được gọi khi mọi cổng tất định đã pass.

**0.7. Khóa quyền ghi** (chi tiết ở mục 3)
- Đầu ra: CODEOWNERS, branch protection, quy tắc deny cho phiên Generator.
- Kiểm chứng: Generator thử sửa `test/x_test.dart` thì bị chặn. PR có diff trong `test/` mà không có duyệt của người thì CI fail.
- Lưu ý: thiết lập quyền và CODEOWNERS là việc của người. Muse chỉ đề xuất file.

### Giai đoạn E: Engine thuần Dart, viết test trước

Với mỗi bước E, người viết test (Contract) viết test và khóa hash **trước**. Sau đó Generator mới code.

**E1. Board và piece**
- Nội dung: lưới N×N (3, 4, 6 lấy từ config), vị trí đúng, trạng thái đặt/chưa đặt.
- Test ID: `ENG-J-01..` trong `test/engine/jigsaw/board_test.dart`.

**E2. Hút mảnh**
- `snap(piecePos, target, tolerance)`. Dung sai tính theo tỉ lệ cạnh mảnh (ví dụ 0.2), lấy từ config.
- Test biên: trong ±N thì hút, ngoài N+1 thì không, các góc.

**E3. Lệnh dùng chung**
- `PlacePiece(pieceId, slot)` dùng cho cả kéo–thả và chạm-chọn-chạm-đặt. `isComplete` phát sự kiện hoàn thành đúng **một lần**.

**E4. Ghép chữ**
- Token hóa, xáo bằng seed, chấp nhận **danh sách đáp án hợp lệ** lấy từ dữ liệu. Không suy luận ngữ pháp.
- Test: nhiều thứ tự hợp lệ, dấu câu, viết hoa.

**E5. Cổng 75%**
- `unlocked(level+1) = solved_owned(level) / total_owned(level) > threshold`, threshold đọc từ config (0.75).
- Test: 19/25 thì mở, 18/25 thì không. Chưa sở hữu đủ thì chỉ tính hình đã sở hữu.
- Đã trả lời (issue #2): ngưỡng = số nguyên nhỏ nhất lớn hơn 75% số hình hiện có của cấp, tính theo số hình thực tế (25 → 19, 10 → 8). Tầng miễn phí không áp cổng. Giải bằng chế độ nào cũng tính.

**E6. Random**
- Rút từ kho đã sở hữu, có seed nên tái lập được, không lặp K hình vừa giải, bật tắt bằng cờ config.
- Test: cùng seed cho cùng chuỗi; 1000 lần rút không trùng hình vừa giải.

**Tiêu chí xong giai đoạn E:** `flutter test test/engine` pass, check_coverage ≥ 80% trên `lib/engine`, check_engine_pure sạch.

**Rủi ro:** dùng `DateTime.now()` hoặc `Random()` không seed trong engine. Phải tiêm clock và rng vào.

### S1: Lát cắt dọc

**S1-01. Nạp nội dung**
- `AssetLoader` đọc `content/manifest.json`, chỉ chấp nhận bản ghi đã qua validator. Dùng 2–3 hình đã duyệt. Nếu chưa có thì dùng ảnh giả trong `test/fixtures`. **Không bao giờ** đưa ảnh giả vào `content/`.
- Kiểm chứng: `flutter test test/data/asset_loader_test.dart`.

**S1-02. Lưu tiến độ bằng drift**
- Bảng `progress(image_id, mode, solved_at, best_time)` và `settings`. Có `schemaVersion`, dump schema bằng `drift_dev`.
- Kiểm chứng: test DAO với DB dạng file (không dùng in-memory) qua hai lần mở. `dart run drift_dev schema dump` ra file trong `drift_schemas/`.

**S1-03. Màn chọn chủ đề**
- 5 chủ đề. Hình bị khóa hiện trạng thái khóa. Mọi nút có `Semantics(label:)`.
- Kiểm chứng: widget test có `meetsGuideline(labeledTapTargetGuideline)` và `androidTapTargetGuideline`. Golden `theme_select.png`.

**S1-04. Màn chơi ghép tranh 3×3**
- Kéo–thả, xem trước, gợi ý.
- Kiểm chứng: `integration_test/jigsaw_snap_test.dart` (thả trong dung sai thì hút, ngoài dung sai thì không) và `completion_event_test`.

**S1-05. Hoàn thành và lưu**
- Màn kết thúc, ghi DB.
- Kiểm chứng: `.maestro/persistence_restart.yaml` (giải xong, `stopApp`, `launchApp`, hình hiện đã giải). Chạy bằng `maestro test .maestro/persistence_restart.yaml`.

**S1-06. Hiệu năng và cỡ chữ**
- Đo hiệu năng: `flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart`. Trong `build/*timeline_summary.json`, cả `90th_percentile_frame_build_time_millis` và `90th_percentile_frame_rasterizer_time_millis` phải < 16.
- Cỡ chữ: test với `TextScaler.linear(2.0)` trên màn 320×568 dp. `tester.takeException()` phải là null.

**Tiêu chí xong S1:** `tool/evaluate.sh S1` pass mọi cổng tất định. Sau đó LLM chấm UX ≥ 8/10.

**Rủi ro S1:** test persistence chỉ chạy in-memory cho kết quả ảo. Đo hiệu năng ở debug mode cũng vô nghĩa.

### S2: Ghép chữ và khả năng truy cập

**S2-01. Màn ghép chữ**
- Chạm token để chuyển xuống hàng đáp án, chạm lại để trả về. Kiểm tra bằng engine E4.

**S2-02. Chạm-chọn-chạm-đặt cho ghép tranh**
- Chọn mảnh rồi chạm ô đích. Dùng chung `PlacePiece`.
- Kiểm chứng: integration test giải trọn 3×3 **không có một cử chỉ kéo nào**.

**S2-03. Lưới 4×4 và 6×6**
- Kiểm chứng: perf test chạy lại với 6×6.

**S2-04. Semantics và trình đọc màn hình**
- Mảnh có nhãn kiểu "Piece 5, row 2 column 1, not placed". Có thông báo `SemanticsService.announce` khi đặt đúng.
- Kiểm chứng: guideline test cộng `textContrastGuideline`. Thử TalkBack thủ công thì ghi vào progress (Paul làm trên máy thật).

**Tiêu chí xong S2:** toàn bộ test ở cỡ chữ 200% pass, golden không lệch.

**Rủi ro S2:** cử chỉ trong khay mảnh xung đột với cuộn. Xem mục 6.

### S3: IAP, khôi phục, quyền sử dụng, cổng 75%

**S3-01. `EntitlementService`**
- Interface với hai bản cài: `RevenueCatEntitlementService` và `FakeEntitlementService`. Mọi test dùng Fake. Khi không có quyền: 2 hình đầu mỗi chủ đề mở, còn lại khóa.

**S3-02. Màn store**
- Giá lấy từ `Offerings` của RevenueCat (`storeProduct.priceString`), không hardcode chuỗi "$3.99".
- Product ID và entitlement ID đặt trong config, do Paul cung cấp.

**S3-03. Khôi phục giao dịch**
- Có nút Restore. Test: Fake trả về quyền, UI mở khóa, sau khi khởi động lại vẫn còn.

**S3-04. Gắn cổng 75% vào UI**
- Chỉ gói cấp 1 được bật. Cấp 2–5 bị ẩn bằng config cho đến khi người duyệt.

**S3-05. Sandbox thật**
- License tester trên Play Console (Paul làm). Đây là bước **ngoài CI**, ghi kết quả vào progress.

**Tiêu chí xong S3:**
- Test trong `test/features/store/` pass với Fake.
- `grep -rn '\$[0-9]' lib/` rỗng.
- Maestro flow mua giả rồi khôi phục pass.

**Rủi ro S3:**
- Quyền sử dụng lưu ở local mà không đồng bộ lại với RevenueCat.
- Commit API key. Key public của RevenueCat được phép nằm trong app, nhưng secret key thì **tuyệt đối không**.

### S4: Analytics và build phát hành

**S4-01. `AnalyticsService`**
- Interface. Sự kiện tối thiểu: `app_open`, `theme_selected`, `puzzle_start`, `puzzle_complete`, `paywall_view`, `purchase`, `restore`. Phục vụ đo D1, D7 và tỉ lệ mua.
- Nhà cung cấp analytics: hỏi James và Paul.
- Kiểm chứng: test bằng Fake ghi sự kiện, đúng thứ tự và đúng tham số.

**S4-02. Quyền riêng tư**
- Không thu thông tin cá nhân. Chuẩn bị dữ liệu cho mục Data safety (Play) và Privacy manifest (iOS sau này).

**S4-03. Build phát hành**
- `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`. Ký số bằng keystore của Paul, đọc qua `key.properties` (đã gitignore).
- Kiểm chứng: tạo được file `.aab`. Dùng `bundletool` đo kích thước và ghi vào progress.

**S4-04. Checklist Closed Testing**
- Tài liệu cho Paul. Muse không tự upload.

**Rủi ro S4:** lộ keystore. Tên sự kiện analytics không thống nhất. Tên sự kiện phải chốt trong contract.

---

## 3. Quy ước và tách quyền

**Nhánh**
- Nhánh làm việc hiện tại: `claude/eloquent-keller-gow6de`.
- Mỗi contract một nhánh con, ví dụ `feat/S1-04-jigsaw-drag`.
- Nhánh của người viết test, ví dụ `test/S1-04`, được merge trước và có duyệt của người.

**Commit**
- Conventional Commits kèm ID contract: `feat(S1-04): snap pieces within tolerance [ENG-J-02, IT-J-01]`.
- Các loại: `feat | fix | test | chore | docs | perf`.

**Tên**
- File: `snake_case.dart`.
- Test ID: `<LỚP>-<FEATURE>-<số>`, với LỚP là `ENG`, `UNIT`, `WID`, `GLD`, `IT`, `E2E` hoặc `PERF`. Mỗi ID nằm trong tên test (`test('ENG-J-02 snaps within tolerance', ...)`) để Evaluator tìm được bằng grep.
- ID hình: `<theme>_<level>_<nn>`, khớp với manifest.

**Khóa file test, bốn lớp**
1. **Lớp agent:** cấu hình quyền của phiên Generator chặn ghi vào `test/**`, `integration_test/**`, `.maestro/**`, `test_driver/**`, `harness/thresholds.yaml`, `harness/ux_rubric.md`, `harness/tests.lock`, `config/**`, `content/**`.
2. **Lớp git:** `tests.lock` lưu sha256. `verify_tests_lock.sh` chạy trong CI và pre-commit. Lệch hash thì fail.
3. **Lớp GitHub:** CODEOWNERS giao các đường dẫn trên cho James và Paul. Branch protection bắt buộc review của code owner.
4. **Lớp quy trình:** Evaluator chạy ở phiên riêng, chỉ đọc mã nguồn. Evaluator chỉ ghi vào `harness/progress.md` và `harness/reports/`. Generator không tự chấm.

Quyền truy cập và CODEOWNERS do người thiết lập. Không agent nào tự mở quyền cho agent khác.

---

## 4. Những việc Muse KHÔNG được làm

1. Không thêm, sửa hay xóa gì trong `content/` hoặc `manifest.json`. Không thêm ảnh chưa qua validator và chưa được Paul duyệt contact sheet. Không dùng ảnh NASA hay Wikimedia, kể cả làm ảnh giữ chỗ.
2. Không sửa file test, file lock, rubric, thresholds. Không thêm `skip:` hay `@Tags(['flaky'])` để vượt cổng. Không hạ ngưỡng coverage.
3. Không hardcode giá, product ID, ngưỡng 75%, dung sai hút, số hình miễn phí hay cờ Random. Tất cả lấy từ config hoặc RevenueCat.
4. Không tạo sản phẩm trên store, không upload build, không động vào keystore, không commit secret (secret key RevenueCat, `key.properties`, `google-services.json` có key nhạy cảm).
5. Không thêm nền tảng web hay desktop, không dùng Playwright, không thêm ngôn ngữ ngoài tiếng Anh.
6. Không làm quá một feature trong một sprint. Không refactor ngoài phạm vi contract.
7. Không gọi LLM chấm UX khi cổng tất định còn fail. Không vượt trần $300. Cập nhật `cost_ledger.csv` sau mỗi vòng.
8. Không bật gói cấp 2–5 trong app.
9. Không thêm SDK theo dõi hay quảng cáo.

---

## 5. Khi nào Muse phải dừng và hỏi người

**Hỏi Paul**
- Package name (applicationId) và bundle ID.
- Keystore.
- Product ID và entitlement ID của RevenueCat.
- Tài khoản tester và kết quả trên máy thật.
- Duyệt contact sheet.
- Xác nhận quy định Closed Testing tại thời điểm nộp.

**Đã trả lời bởi James (issue #2, Paul đã duyệt)**
- Cổng 75%: tính theo số hình thực tế của cấp (25 → 19, 10 → 8). Tầng miễn phí không áp cổng.
- Cổng tính cả hai chế độ chơi.
- Analytics: Firebase Analytics.
- Nội dung trả phí: soft launch (50 hình) và tầng miễn phí đóng gói sẵn trong app. Cấp 2–5 tải về sau khi mua bằng Play Asset Delivery (Android) và on-demand resources (iOS), entitlement của RevenueCat quyết định pack nào được tải.

**Hỏi James (còn mở)**
- Đổi schema drift sau khi đã phát hành.
- Mọi thay đổi với file test hoặc ngưỡng.

**Theo quy định harness**
- Cùng một lỗi FAIL hai lần: dừng.
- 3 vòng FAIL trên một contract: dừng.
- Chi phí đạt 80% trần ($240): báo trước.
- Kiểm thử tất định không ổn định (flaky trên emulator): báo người, không tự nới.

**Khi có mâu thuẫn**
- Contract mâu thuẫn với bối cảnh đã chốt.
- Cần thêm quyền Android mới (INTERNET đã có; các quyền khác phải hỏi).
- Kích thước AAB vượt khoảng 150 MB.

---

## 6. Rủi ro kỹ thuật Flutter: kéo–thả và ảnh lớn trên máy Android yếu

**Ảnh và bộ nhớ**
- Ảnh gốc có cạnh ngắn ≥ 2048 px. Một ảnh 2048×3072 RGBA tốn khoảng 25 MB RAM sau khi giải mã. **Không ship ảnh gốc.**
- Pipeline xuất thêm `play.webp` (cạnh dài khoảng 1600 px, chất lượng khoảng 85) và `thumb.webp` (khoảng 320 px).
- Khi nạp, dùng `ResizeImage` hoặc `cacheWidth` theo kích thước bảng × `devicePixelRatio`, có trần (ví dụ 1440 px).
- Lưới chọn chủ đề chỉ dùng thumb.
- Đặt `PaintingBinding.instance.imageCache.maximumSizeBytes` khoảng 64–100 MB. Gọi `evict` ảnh khi rời màn chơi.
- **Không cắt ảnh thành 36 ảnh con.** Giải mã một `ui.Image` duy nhất, rồi vẽ từng mảnh bằng `canvas.drawImageRect(src, dst)` trong `CustomPainter`. Hình răng cưa (nếu có) dùng `clipPath` cache sẵn theo mảnh.
- Cách đo: `adb shell dumpsys meminfo <pkg>` khi đang chơi 6×6. Mục tiêu: Total PSS dưới khoảng 250 MB trên máy 2–3 GB RAM. Ghi số vào progress.

**Kéo–thả**
- Không dùng 36 `Draggable` lồng `DragTarget` và rebuild cả cây. Thay vào đó dùng một `Listener` hoặc `GestureDetector` trên toàn bảng. Vị trí mảnh nằm trong `ValueNotifier`. Mảnh đang kéo bọc `RepaintBoundary` và di chuyển bằng `Transform.translate`, nên khi kéo chỉ một layer repaint.
- Hit test tự làm bằng engine: tìm mảnh trên cùng theo z-order.
- Bỏ qua pointer thứ hai khi đa chạm.
- **Cử chỉ hệ thống Android:** vuốt mép để Back có thể cướp thao tác kéo gần mép màn hình. Chừa lề khoảng 24 dp, hoặc dùng `SystemGestureExclusion` qua platform channel (chỉ có từ Android 10, hệ thống giới hạn khoảng 200 dp mỗi cạnh).
- **Khay mảnh cuộn được** xung đột với kéo. Kéo mảnh bắt đầu bằng long-press, hoặc phân hướng (cuộn ngang, kéo mảnh lên trên). Chạm-chọn-chạm-đặt là đường dự phòng luôn có.
- **Impeller** là mặc định trên Android mới, nhưng một số GPU đời cũ có lỗi driver. Thử trên máy thật cả `--enable-impeller` và `--no-enable-impeller`. Nếu có lỗi, ghi model máy vào progress và hỏi James trước khi tắt Impeller trong manifest.

**Cách đo hiệu năng**
- Chỉ đo ở **profile mode**. Dùng `IntegrationTestWidgetsFlutterBinding.traceAction` bao quanh kịch bản kéo 20 mảnh trên lưới 6×6. Dùng `integrationDriver(responseDataCallback: ... writeResponseData)` để xuất timeline summary.
- Emulator chỉ dùng để xem xu hướng. **Cổng p90 < 16 ms chốt trên máy thật cấu hình thấp** (Paul chọn một máy chuẩn, ví dụ Android Go hoặc máy 2–3 GB RAM). Ghi model máy vào `thresholds.yaml`.
- Nếu CI chỉ có emulator: đặt cổng emulator tách riêng, ghi rõ là "indicative" trong contract. Không trộn với cổng trên máy thật.
- Theo dõi thêm thời gian từ lúc chạm hình đến lúc ảnh hiện lên (mục tiêu dưới 500 ms trên máy chuẩn), đo bằng `Timeline` hoặc `Stopwatch` trong perf test.

**Golden và layout**
- Golden phụ thuộc font và nền tảng. Chỉ chạy trên Linux CI, font đóng gói, tắt animation.
- Test tràn layout phải chạy ở cả 200% chữ lẫn màn hẹp 320 dp. Tràn thường chỉ hiện khi gặp cả hai.

**Kích thước app**
- 125 hình × (play khoảng 350 KB + thumb khoảng 30 KB) ≈ 48 MB. Soft launch với 50 hình thì ổn.
- Khi thêm cấp 2–5 sẽ phải chọn tải về sau khi mua hay đóng gói sẵn. Đây là quyết định của James (mục 5).
