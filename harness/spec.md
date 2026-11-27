# Spec — Game xếp hình 5 chủ đề (Planner)

Bản rút gọn có thẩm quyền của kế hoạch tổng hợp (Game-puzzle issue #1; bản đầy đủ:
`ke-hoach-game-xep-hinh-dong-vat-2026-11-27.md` trong workspace của Paul).
Khi có mâu thuẫn, thứ tự ưu tiên: quyết định của Paul > issue #1/#2 > file này.

## Sản phẩm

Game xếp hình thư giãn, native **Flutter** (Android trước, iOS sau), **chỉ tiếng Anh**,
không server, tiến độ lưu local (SQLite qua drift).

- **5 chủ đề:** Động vật, Phong cảnh, Vũ Trụ, Bản Đồ, Biểu Tượng Nổi Tiếng.
- **Mỗi chủ đề 5 cấp × 25 hình.** Soft launch: Cấp 1, 10 hình/chủ đề (50 hình).
  Full launch: Cấp 1 đủ 25 hình/chủ đề (125 hình). Cấp 2–5 là content drop sau,
  chỉ mở bán khi cấp đó đã hoàn thiện.
- **2 chế độ chơi trên cùng một hình:** ghép tranh (jigsaw) và ghép chữ
  (xếp lại các token thành đoạn mô tả). Cả hai chế độ đều tính vào tiến độ mở cổng.
- **2 chế độ nội dung:** Curated (mặc định — Paul chọn hình, thứ tự, văn bản) và
  Random (rút có seed từ kho hình đã sở hữu + đã duyệt, vẫn qua cổng 75%,
  không lặp hình vừa giải; bật/tắt bằng cờ config).

## Tiến độ và cổng 75%

- Mở cấp tiếp theo của một chủ đề khi: `solved_owned(level) / total_owned(level) > 0.75`,
  tức số hình cần giải = số nguyên nhỏ nhất lớn hơn 75% số hình hiện có của cấp
  (25 → 19; 10 → 8). Ngưỡng đọc từ config, không hardcode.
- Tầng miễn phí (2 hình/chủ đề, tổng 10) là mẫu cố định, không áp cổng.
- Cổng chỉ là cơ chế chơi — không thu thêm tiền tại cổng.

## Kiếm tiền

- Miễn phí: 2 hình đầu mỗi chủ đề.
- **Gói nền $3.99:** toàn bộ Cấp 1. **Gói cấp $1.99/cấp** cho Cấp 2–5 (tạo product
  trên store chỉ khi cấp đó hoàn thiện — không bán trước). **Gói "Trọn bộ"** giảm giá
  khi đủ 5 cấp. Có thể giảm giá 1–2 tuần đầu ra mắt.
- Thanh toán qua **RevenueCat** (`purchases_flutter`): StoreKit 2 + Play Billing,
  có Restore; entitlement quyết định quyền sở hữu và pack nào được tải.
- Nội dung: miễn phí + soft launch **đóng gói sẵn trong app**; gói Cấp 2–5
  **tải về sau khi mua** (Play Asset Delivery / iOS on-demand resources).

## Nội dung và bản quyền

- Chỉ ảnh **public domain qua API CC0** của các bảo tàng: The Met, AIC, Cleveland,
  NGA, Rijksmuseum, Smithsonian. **Không dùng ảnh NASA. Không dùng Wikimedia làm
  nguồn chính.** Ngoại lệ duy nhất còn hiệu lực: BHL (minh họa tác giả mất trước
  1926) — phải ghi căn cứ PD + người duyệt trong manifest.
- Mọi hình phải qua **validator** (`content_pipeline/`): manifest đủ trường
  (gồm sha256, pHash chống trùng, cạnh ngắn ≥ 2048px, điểm độ phức tạp),
  chặn mặc định khi thiếu. Hình chưa được Paul duyệt qua contact sheet thì
  không vào `content/`.
- Văn bản mô tả tự viết hoặc AI soạn rồi người biên tập; câu ngắn, đơn giản.
  Màn hình credits trong app sinh tự động từ manifest.
- Chủ đề Bản Đồ: lọc bản đồ tranh chấp chủ quyền nếu bán tại Việt Nam.

## Khả năng truy cập (làm từ S2, không để cuối)

- Font Atkinson Hyperlegible hoặc OpenDyslexic (giấy phép OFL).
- **Chạm-chọn–chạm-đặt** thay thế kéo–thả (WCAG 2.5.7).
- Semantics label cho mọi nút và mảnh; không tràn layout ở cỡ chữ 200%.

## Analytics

- **Firebase Analytics.** Sự kiện tối thiểu: `app_open`, `theme_selected`,
  `puzzle_start`, `puzzle_complete`, `paywall_view`, `purchase`, `restore`.
- Mục tiêu soft launch (đo, không suy đoán): D1 ≥ 35%, D7 ≥ 12%,
  tỉ lệ chuyển đổi mua ≥ 2%.

## Lộ trình sprint (chi tiết: harness/MUSE_STEPS.md)

- **Giai đoạn 0:** repo, CI, khung harness, khóa quyền ghi.
- **Giai đoạn E:** engine thuần Dart, viết test trước (board/piece, hút mảnh,
  lệnh dùng chung, ghép chữ, cổng 75%, random).
- **S1:** lát cắt dọc — nạp nội dung, drift, màn chọn chủ đề, chơi 3×3, lưu tiến độ.
- **S2:** ghép chữ + khả năng truy cập.
- **S3:** IAP + entitlement + paywall + restore + gắn cổng 75% vào UI.
- **S4:** analytics + build phát hành + checklist Closed Testing.

## Việc của người (không agent nào tự làm)

Paul: tài khoản store, ký số/keystore, thiết bị thật, Closed Testing/TestFlight,
duyệt nội dung, applicationId + RevenueCat ID.
James: code + vận hành harness trong Muse + đồng bộ file kế hoạch.
Claude: thiết kế build/test/pipeline nội dung.

Ghi chú quản trị repo: ruleset "Protect main" đã bật sẵn (có bypass cho chủ
repo). CODEOWNERS chỉ có một tài khoản (@yameshop95-png) và GitHub không cho
tác giả tự duyệt PR của mình, nên merge thực tế đi qua bypass của chủ repo —
lớp chặn thật là tests.lock chạy trong CI, không phải lượt duyệt.
**Luật merge (Opus nêu khi merge PR #8, 27/11/2026): không dùng bypass để
merge khi CI đang đỏ.** Paul đã bật "required status checks" cho
hai job "Static gates" và "Unit tests + coverage" (tên hiển thị của job,
không phải id `static`/`unit`) trong ruleset "Protect main" ngày
27/11/2026, nên luật này đã thành chặn cứng; tới lúc đó, luật trên giấy này là cam kết của quy trình.
