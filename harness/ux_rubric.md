# UX rubric — thang chấm của Evaluator (LLM)

Chỉ chấm **sau khi mọi cổng tất định đã pass** (xem tool/evaluate.sh).
Mỗi mục chấm 4 / 6 / 8 / 10 theo mô tả dưới đây. **Đạt = cả 4 mục ≥ 8**
(pass_score trong thresholds.yaml). Dưới ngưỡng ở bất kỳ mục nào = FAIL vòng đó.

## 1. Độ sâu sản phẩm (Product depth)

- **4:** Chỉ có khung màn hình; luồng chính đứt đoạn hoặc phải đoán mới dùng được.
- **6:** Luồng chính chạy được nhưng thiếu trạng thái phụ (rỗng, lỗi, đang tải, đã khóa).
- **8:** Luồng chính + các trạng thái phụ đầy đủ theo contract; không có nút chết,
  không có màn hình cụt.
- **10:** Như 8, cộng xử lý tình huống biên mà contract chưa liệt kê (xoay máy,
  thoát giữa chừng, dữ liệu cũ) một cách nhất quán với phần còn lại của app.

## 2. Chức năng (Functionality)

- **4:** Có tính năng hiển thị nhưng không hoạt động đúng với thao tác thật.
- **6:** Hoạt động đúng ở đường vui vẻ (happy path); sai ở thao tác lặp lại,
  thao tác nhanh, hoặc thứ tự thao tác khác thường.
- **8:** Đúng ở cả thao tác lặp/hủy/giữa chừng; kết quả khớp với dữ liệu đã lưu
  sau khi khởi động lại app.
- **10:** Như 8, cộng phản hồi tức thì và rõ ràng cho mọi thao tác (không có
  khoảng lặng không giải thích trên 300 ms ở thao tác chính).

## 3. Thiết kế hình ảnh (Visual design)

- **4:** Lệch lưới, tràn chữ, tương phản kém, khoảng cách tùy tiện.
- **6:** Gọn gàng nhưng thiếu nhất quán (cỡ chữ, khoảng đệm, trạng thái nút
  thay đổi giữa các màn hình).
- **8:** Nhất quán toàn app; không tràn ở cỡ chữ 200% và màn 320 dp; vùng chạm
  đạt chuẩn; trạng thái khóa/mở phân biệt rõ mà không chỉ dựa vào màu.
- **10:** Như 8, cộng bản sắc thị giác riêng (không giống template mặc định)
  và chuyển động có chủ đích, không gây chóng mặt, tắt được khi hệ thống yêu cầu.

## 4. Chất lượng code (Code quality)

- **4:** Logic nằm trong widget; engine import Flutter; số liệu hardcode
  (giá, ngưỡng, dung sai) rải trong code.
- **6:** Tách lớp đúng nhưng còn trùng lặp rõ rệt hoặc tên gọi gây hiểu nhầm;
  test chỉ phủ đường vui vẻ.
- **8:** Engine thuần Dart, mọi hằng số từ config, test phủ cả biên và lỗi;
  `flutter analyze` sạch với lint strict.
- **10:** Như 8, cộng code đọc như tài liệu: contract ID truy được từ test,
  không cần comment giải thích lại điều code đã nói rõ.
