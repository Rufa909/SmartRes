# Chatbot tư vấn món cho khách

## Cách dùng

Trên trang thực đơn, chạm **Trợ lý chọn món**. Khách có thể hỏi tên món, giá, hoặc nhờ gợi ý theo khẩu vị như món chay, đồ uống, ăn nhẹ và món cay. Có vài câu hỏi mẫu để bắt đầu.

Chatbot đưa thẻ món đang bán kèm giá và nút **Thêm vào giỏ**. Nút này chỉ thêm món vào giỏ; khách vẫn xem lại và tự xác nhận gọi món như trước. Nếu món ngừng bán trong lúc khách đang chat, món đó không được thêm.

## API và dữ liệu

- `POST /api/chatbot/message`
- Body: `{ "message": "Gợi ý đồ uống", "cartItemIds": [1] }`
- API lấy thực đơn đang bật bán từ MySQL mỗi lần hỏi, không tin giá/tên do trình duyệt gửi lên.
- Tối đa 400 ký tự mỗi câu hỏi; phản hồi chỉ chứa món còn bán và bỏ qua món đã có trong giỏ.
- Nếu Gemini hoạt động, AI Service dùng Gemini để hiểu câu hỏi tiếng Việt tự nhiên và trả ID món gợi ý. Customer API kiểm tra ID đó với thực đơn hiện hành rồi tự lấy lại giá/tên; model không được tạo giá hay gửi đơn.
- Khi thiếu API key, AI Service tắt hoặc gọi Gemini lỗi, Customer API tự dùng luật gợi ý cục bộ. Phản hồi API có `provider` là `gemini` hoặc `rule-based`.
- Không gửi tên khách, mã bàn, token phiên hoặc nội dung đơn đến Gemini. Chỉ gửi câu hỏi, ID món trong giỏ và mô tả thực đơn.

## Bật Gemini free tier để demo

1. Tạo API key ở [Google AI Studio](https://aistudio.google.com/apikey).
2. Điền key vào `GEMINI_API_KEY` trong file `.env` ở thư mục gốc. Không dán key vào mã nguồn, frontend hoặc chat; `.env` đã được Git bỏ qua. Mặc định chatbot dùng model `gemini-3.5-flash-lite`.
3. Cài môi trường FastAPI lần đầu:

   ```powershell
   cd apps/ai-service
   python -m venv .venv
   .venv\Scripts\activate
   pip install -e .
   ```

4. Mở terminal này tại thư mục gốc repository và chạy `python -m uvicorn app.main:app --app-dir apps/ai-service --reload --port 8000`.
5. Terminal khác chạy `npm run dev:customer`, sau đó mở QR và hỏi chatbot.

Nếu không có key hoặc AI Service chưa chạy, chatbot vẫn dùng rule-based nhưng câu trả lời sẽ ít linh hoạt hơn. Google có thể dùng dữ liệu Gemini API ở free tier để cải thiện sản phẩm; trước khi dùng dữ liệu khách thật, kiểm tra điều khoản hiện hành và tránh gửi thông tin cá nhân.

## Chạy

Giao diện dùng Customer API và web; Gemini cần FastAPI riêng theo các bước trên. Chạy `npm run dev:customer`, mở một QR bàn, rồi chạm **Trợ lý chọn món**.
