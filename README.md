# DMoney

Vue 3 + Supabase, dạng PWA (cài được lên điện thoại và PC), host free.

## 1. Tạo Supabase project (free)
1. Vào https://supabase.com → New project.
2. Vào SQL Editor, chạy nội dung file `supabase_schema.sql`. Với project đã tạo bảng `entries`, file này cũng bao gồm migration để tự gán giao dịch cũ vào nguồn **Tiền mặt**.
3. Vào Project Settings → API, lấy `Project URL` và `anon public key`.

### Bật đăng nhập bằng Magic Link
1. Trong Supabase Dashboard, vào **Authentication → Providers → Email** và bật Email provider.
2. Để thử nhanh, có thể tắt **Confirm email**. Khi dùng production, nên giữ bật để xác thực địa chỉ email.
3. Nếu project đã có giao dịch trước khi thêm đăng nhập, hãy gán `user_id` của chủ sở hữu cho các dòng cũ trong SQL Editor. Schema giữ nguyên các dòng đó và ẩn chúng cho đến khi được gán chủ sở hữu, tránh làm lộ dữ liệu.

## 2. Cấu hình local
Tạo file `.env` ở thư mục gốc:
```
VITE_SUPABASE_URL=https://xxxx.supabase.co
VITE_SUPABASE_ANON_KEY=xxxxxxxx
```

## 3. Chạy thử
```bash
npm install
npm run dev
```

## 4. Deploy free (không cần VPS)
- Đẩy code lên GitHub.
- Vào https://vercel.com hoặc https://app.netlify.com → Import từ GitHub.
- Thêm 2 biến môi trường `VITE_SUPABASE_URL` và `VITE_SUPABASE_ANON_KEY` trong phần Environment Variables của project trên Vercel/Netlify.
- Deploy — có sẵn HTTPS, domain miễn phí dạng `ten-app.vercel.app`.

## 5. Cài lên điện thoại
Mở trang deploy trên Chrome/Safari mobile → menu → "Add to Home Screen". App chạy như app thật nhờ cấu hình PWA sẵn trong `vite.config.js`.

## Ghi chú
- Xoá 1 dòng: chạm/click vào dòng đó trong sổ.
- Số dư "stamp" ở góc trên luôn là số dư mới nhất và được tính luỹ kế trên toàn bộ giao dịch, đổi màu đỏ khi âm.
- Chọn **Điều chỉnh** để đặt lại số dư hiện tại. Ứng dụng tự thêm một dòng chênh lệch vào sổ, nên số dư sau đó vẫn được tính liên tục và không mất lịch sử.
- Mỗi tài khoản chỉ có thể đọc và thay đổi giao dịch có `user_id` của chính mình.
