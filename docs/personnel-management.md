# Quản lý nhân sự

Vào tài khoản **Quản lý → Truy cập nhanh → Quản lý nhân sự**. Danh sách hỗ trợ tìm theo họ tên/tên đăng nhập và lọc Nhân viên, Bếp, Thu ngân.

- **Thêm tài khoản**: nhập họ tên, tên đăng nhập, chọn vai trò và mật khẩu. Có nút tạo mật khẩu ngẫu nhiên. Nhập lại mật khẩu rồi lưu. Sau khi lưu thành công, quản lý có thể sao chép tên đăng nhập và mật khẩu để giao trực tiếp cho nhân sự.
- **Sửa tài khoản**: chạm vào nhân sự hoặc chọn menu ba chấm → Sửa tài khoản. Có thể đổi họ tên, tên đăng nhập và vai trò.
- **Cấp lại mật khẩu**: menu ba chấm → Cấp lại mật khẩu. Nhập mật khẩu mới hai lần hoặc tạo ngẫu nhiên, rồi xác nhận cấp lại. Không xem lại được mật khẩu cũ.
- **Xóa tài khoản**: menu ba chấm → Xóa tài khoản → xác nhận. Tài khoản biến mất khỏi danh sách và không thể đăng nhập. Database giữ bản ghi ở trạng thái ngừng hoạt động để bảo toàn lịch sử; tên đăng nhập cũ vẫn được giữ, không cấp trùng.

Chỉ quản lý có quyền thực hiện các thao tác này. Không tạo, sửa hoặc xóa tài khoản quản lý từ màn hình này. Mật khẩu tối thiểu 6 ký tự và được lưu dưới dạng băm scrypt. Danh sách và phản hồi API không chứa mật khẩu hoặc giá trị băm. Mật khẩu vừa cấp chỉ hiển thị trong hộp thoại kết quả của lần cấp đó.

Sửa tài khoản, cấp lại mật khẩu và xóa tài khoản đều vô hiệu hóa phiên đăng nhập cũ ở lần gọi API tiếp theo. Nhân sự cần đăng nhập lại với thông tin mới. API dùng phiên bản tài khoản để chặn ghi đè từ hai thiết bị quản lý đang mở cùng lúc.

API nhân viên tự bổ sung cột `users.session_version` khi khởi động, không xóa dữ liệu hiện có. Sau cập nhật, khởi động lại API nhân viên và build/cài lại app trên các thiết bị. Kiểm thử riêng: `npm --workspace apps/api run test:users`.
