# Quản lý thời gian và trạng thái món ăn

Tech stack của dự án: backend Node.js + TypeScript + Express + MySQL; ứng dụng quản lý Flutter/Dart. Không bổ sung framework hoặc database khác.

Vào **Quản lý → Truy cập nhanh → Thời gian và trạng thái ra món**. Danh sách mặc định thu gọn, hiển thị tên món, số lượng, bàn, trạng thái và thời gian: món chưa phục vụ hiện **Đã chờ** từ lúc tạo món đến hiện tại; món đã phục vụ hiện **Tổng** từ lúc tạo đến lúc phục vụ. Thời gian chờ cập nhật theo lần đồng bộ mỗi 5 giây, tổng của món đã phục vụ không tiếp tục tăng. Nhấn một món để mở mã đơn, ghi chú, bốn mốc thời gian và bốn thời lượng; nhấn lại để thu gọn. Tự cập nhật mỗi 5 giây; hỗ trợ tìm tên món/bàn/mã đơn, lọc bốn trạng thái, lọc ngày tạo theo giờ Việt Nam và phân trang 30 dòng. Mục **Đang chờ** gom `preparing`, `cooking`, `completed`, loại trừ `served`; đây chỉ là bộ lọc, không thêm trạng thái mới. Mặc định chỉ hiện món gọi trong hôm nay theo giờ Việt Nam. Chọn ngày trong bộ lọc để xem ngày trước; nút Về hôm nay trả về ngày hiện tại. Các mục đang chờ xếp thời điểm tạo món tăng dần (order trước nằm trên), trùng giờ theo ID tăng dần. Riêng mục Đã phục vụ xếp thời điểm phục vụ giảm dần (vừa phục vụ nằm trên), trùng giờ theo ID giảm dần. Thứ tự áp dụng từ backend trước khi phân trang. Số lượng trên các bộ lọc là số dòng món, không phải số phần ăn. Có thể xem món đã thanh toán; đơn bị hủy không nằm trong báo cáo.

## Bốn trạng thái và thời điểm ghi nhận

| Trạng thái | Nhãn | Mốc lưu trong `order_items` |
| --- | --- | --- |
| `preparing` | Chờ bếp | `created_at`: thời điểm tạo dòng món |
| `cooking` | Đang nấu | `cooking_started_at`: bếp bấm bắt đầu nấu |
| `completed` | Chờ phục vụ | `completed_at`: bếp bấm hoàn thành |
| `served` | Đã phục vụ | `served_at`: nhân viên xác nhận phục vụ |

MySQL ghi thời gian bằng `CURRENT_TIMESTAMP`; không lấy giờ từ điện thoại. Các mốc nấu/hoàn thành/phục vụ được ghi trong cùng câu UPDATE có điều kiện chuyển trạng thái. Hai thiết bị gửi lặp không ghi đè thời gian đã có và không thể đưa món lùi bước. Món thêm sau vào hóa đơn có `created_at` riêng, không dùng thời điểm tạo đơn đầu tiên.

## Công thức

- Chờ bếp: `cooking_started_at - created_at`.
- Nấu: `completed_at - cooking_started_at`.
- Chờ bưng: `served_at - completed_at`.
- Tổng ra món: `served_at - created_at`.

API trả thời lượng bằng giây; app hiển thị giờ/phút/giây, ví dụ `4 phút 30 giây`. Dòng gọi món thu gọn chỉ hiện giờ `HH:mm:ss`, không kèm ngày hoặc cụm → hiện tại. Món ở `preparing`, `cooking` hoặc `completed` có tổng thời gian chờ hơn 20 phút (lớn hơn 1.200 giây) hiển thị thời lượng màu đỏ; món `served` không áp dụng cảnh báo này. Khi một giai đoạn chưa kết thúc, thời lượng hoàn tất vẫn để trống, đồng thời hiển thị riêng thời gian đang ở trạng thái hiện tại (`bây giờ - mốc bắt đầu giai đoạn`). Tổng đã chờ của món chưa phục vụ được hiển thị riêng với tổng ra món đã hoàn tất.

Mốc thiếu, hoặc cặp thời gian có thứ tự không hợp lệ, không được tính thành 0. App hiển thị **Chưa ghi nhận / Chưa đủ mốc**. Món cũ không tự lấy giờ migration hay giờ tạo đơn làm thời điểm tạo món. Món được thêm trực tiếp ở trạng thái đã phục vụ vẫn giữ mốc nấu/hoàn thành chưa ghi nhận; không tạo các mốc giả.

## Lưu trữ và API

Hai API nhân viên/khách tự chạy migration bổ sung khi khởi động. Có thể chạy riêng:

```powershell
npm --workspace apps/api run db:item-timing
```

Migration thêm các cột thiếu với giá trị NULL cho dữ liệu cũ, đặt mặc định thời điểm hiện tại chỉ cho dòng mới và tạo chỉ mục `(created_at,id)`. Không xóa dữ liệu cũ.

Endpoint chỉ cho quản lý: `GET /api/staff/management/item-timings`.

Tham số: `status` (`pending` cho Đang chờ, hoặc một trong bốn trạng thái), `q` (tên món/bàn/mã đơn), `date` (`YYYY-MM-DD`, ngày Việt Nam), `offset`, `limit` (1–100, mặc định 30). Không truyền `date` thì backend tự chọn hôm nay theo giờ Việt Nam, kể cả khi qua nửa đêm; không còn chế độ xem tất cả ngày. Khi lọc ngày, dòng thiếu `created_at` không được tự gán vào ngày nào. Phản hồi gồm `items`, `counts`, `total`, `offset`, `limit`, `date` (ngày thực tế đã áp dụng), `generatedAt`. Mỗi món có bốn mốc ISO UTC, `durations`, `currentStageElapsedSeconds` và `totalElapsedSeconds`.

Kiểm thử: `npm --workspace apps/api run test:item-timing` và `flutter test test/item_timing_test.dart` trong thư mục `smartresapp`.
