# Bảng phân công công việc — James × Claude

Cập nhật lần cuối: 28/11/2026, 07:40 (giờ Melbourne) — James điều phối.

Cách dùng: mỗi bên tự xem phần của mình và làm theo. Xong một mốc thì cập nhật trạng thái ngay trong file này (qua PR) hoặc báo ở kênh ghi kèm. Kênh phối hợp của dự án game: **Game-puzzle issue #2**. Luật chung: James làm xong thì đăng lên issue, Opus soát, Claude merge và báo lại trên issue; Opus đã OK và nêu bước tiếp theo thì James tự làm tiếp, không chờ Paul (luật Paul chốt 27/11/2026).

## 1. Phòng Game Puzzle build (James)

- **[Vừa mở khóa — làm ngay]** E6 Random picker đã merge vào main (PR #26, commit `620769af`). Việc bây giờ: đồng bộ local về main mới → kiểm tra tiêu chí thoát Phase E (`flutter test test/engine` pass, engine coverage ≥ 80%, purity sạch) → đi bước tiếp theo theo `harness/MUSE_STEPS.md`, mở đầu bằng danh sách bước như mọi bước E trước.
- Phase E đã đủ E1–E6 trên main: Board/piece, snapTarget, PlacePiece + TrayOrder, word engine, cổng 75%, Random picker.

## 2. Claude / Opus (soát và merge)

- Chồng E6 đã soát và merge xong (PR #26, commit `620769af`); PR #24/#25 đã bao hàm. Cách đọc cửa sổ không-lặp James gắn cờ (K_eff id phân biệt gần nhất trong pool, ca phân biệt ENG-R-06) coi như đã được chấp nhận qua merge này — nếu Opus có ý khác, ghi rõ trên issue #2.
- Hiện không có chồng PR nào chờ soát. Việc tiếp theo: chờ James nộp bước kế tiếp sau Phase E và soát theo cùng quy trình (Opus kiểm tra → OK thì Claude merge → báo merge commit trên issue #2).

## 3. Chờ Paul quyết (đang chặn việc khác)

- **Ads 3–5/12/2026:** cấp quyền cho Paul James trên tài khoản quảng cáo 6999… (từ phía profile Hiến Cút) hoặc chốt chạy trên tài khoản 2709…; duyệt ngân sách 45 AUD (15 AUD/ngày × 3 ngày). Ba bản nháp quảng cáo giữ nguyên cho đến khi Paul nói khác.

## 4. James điều phối (chat chính)

- Giám sát phòng Game Puzzle build, canh issue #2 mỗi 10 phút và tự chuyển tin phía Claude/Opus vào phòng build.
- Canh bảng Agentic OS: việc mới Paul ghi trên bảng tự chảy vào phòng phụ trách mỗi 10 phút qua cây cầu đã nối 28/11/2026.
