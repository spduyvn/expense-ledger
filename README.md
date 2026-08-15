# DMoney

Vue 3 + Supabase, dạng PWA (cài được lên điện thoại và PC), host free.

## 1. Tạo Supabase project (free)
1. Vào https://supabase.com → New project.
2. Vào SQL Editor, chạy nội dung file `supabase_schema.sql`. Với project đã tạo bảng `entries`, file này cũng bao gồm migration để tự gán giao dịch cũ vào nguồn **Tiền mặt**.
3. Vào Project Settings → API, lấy `Project URL` và `anon public key`.

### Bật đăng nhập bằng Magic Link
1. Trong Supabase Dashboard, vào **Authentication → Providers → Email** và bật Email provider.
2. Để thử nhanh, có thể tắt **Confirm email**. Khi dùng production, nên giữ bật để xác thực địa chỉ email.
3. Vào **Authentication → URL Configuration**, thêm `http://localhost:3000/**` vào **Redirect URLs** để Magic Link quay về đúng local app. Khi deploy, thêm URL production (ví dụ `https://ten-app.vercel.app/**`) tại đây. Có thể đặt **Site URL** là URL production; URL callback local vẫn được cho phép qua Redirect URLs.
4. Nếu project đã có giao dịch trước khi thêm đăng nhập, hãy gán `user_id` của chủ sở hữu cho các dòng cũ trong SQL Editor. Schema giữ nguyên các dòng đó và ẩn chúng cho đến khi được gán chủ sở hữu, tránh làm lộ dữ liệu.

## 2. Cấu hình local
Tạo file `.env` ở thư mục gốc:
```
VITE_SUPABASE_URL=https://xxxx.supabase.co
VITE_SUPABASE_ANON_KEY=xxxxxxxx
VITE_APP_ENV=local
```

Khi `VITE_APP_ENV=local`, ứng dụng tự tạo phiên **Anonymous Sign-In** và không hiển thị màn hình Magic Link hay cần mật khẩu. Bật Anonymous Sign-Ins trong **Supabase Dashboard → Authentication → Providers → Anonymous** trước khi chạy local. Phiên test được lưu trong trình duyệt nên dữ liệu tiếp tục được dùng ở các lần chạy sau; xoá site data để tạo phiên test mới.

Với Supabase RLS, không thể tự đăng nhập vào một user email cố định chỉ từ frontend mà không có mật khẩu, Magic Link hoặc backend bảo mật. Anonymous Sign-In là lựa chọn phù hợp để bỏ đăng nhập khi test local mà vẫn tuân thủ RLS.

## 3. Chạy thử
```bash
npm install
npm run dev
```

Ứng dụng local chạy cố định tại `http://localhost:3000`. Nếu port này đang được dùng, Vite sẽ báo lỗi thay vì tự chuyển sang port khác, để URL Magic Link luôn khớp với Redirect URLs trong Supabase.

## 4. Deploy free (không cần VPS)
- Đẩy code lên GitHub.
- Vào https://vercel.com hoặc https://app.netlify.com → Import từ GitHub.
- Thêm `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` và `VITE_APP_ENV=production` trong phần Environment Variables của project trên Vercel/Netlify.
- Deploy — có sẵn HTTPS, domain miễn phí dạng `ten-app.vercel.app`.

## 5. Cài lên điện thoại
Mở trang deploy trên Chrome/Safari mobile → menu → "Add to Home Screen". App chạy như app thật nhờ cấu hình PWA sẵn trong `vite.config.js`.

## Ghi chú
- Xoá 1 dòng: chạm/click vào dòng đó trong sổ.
- Số dư "stamp" ở góc trên luôn là số dư mới nhất và được tính luỹ kế trên toàn bộ giao dịch, đổi màu đỏ khi âm.
- Chọn **Điều chỉnh** để đặt lại số dư hiện tại. Ứng dụng tự thêm một dòng chênh lệch vào sổ, nên số dư sau đó vẫn được tính liên tục và không mất lịch sử.
- Mỗi tài khoản chỉ có thể đọc và thay đổi giao dịch có `user_id` của chính mình.

## Điều chỉnh số dư và theo dõi nợ

- `entries.entry_type` là `transaction` cho giao dịch thu/chi bình thường hoặc `adjustment` cho điều chỉnh số dư thủ công. Adjustment vẫn cập nhật số dư tài khoản và tổng số dư, nhưng không tham gia số dư ngày hoặc số dư chạy trên từng dòng.
- Hệ thống nợ dùng ba bảng: `debt_accounts` (mỗi khoản nợ), `debt_entries` (dư đầu kỳ, phát sinh và thanh toán), và `debt_month_plans` (lịch trả theo tháng). **Tổng nợ** là tổng luỹ kế từng khoản; **Cần trả tháng này** là kế hoạch tháng trừ số đã trả trong tháng. Khi thanh toán, database ghi đồng thời một giao dịch chi tiền và một dòng trả nợ nên số dư tiền/tổng nợ luôn khớp. Khi có phát sinh mới, người dùng có thể phân bổ số tiền đó vào các tháng mong muốn.
- Sau khi cập nhật mã, chạy lại toàn bộ `supabase_schema.sql` trong Supabase SQL Editor trước khi dùng tính năng khoản nợ mới. Dữ liệu ở bảng `debts` cũ không được tự chuyển đổi vì không có tên khoản nợ để gán chính xác; hãy tạo lại các khoản đang còn nợ trong màn hình **Quản lý khoản nợ**.
- Với database đã có dữ liệu cũ, chạy migration sau trong SQL Editor (file `supabase_schema.sql` cũng đã có đầy đủ):

```sql
alter table entries add column if not exists entry_type text;
update entries set entry_type = 'transaction' where entry_type is null;
alter table entries alter column entry_type set default 'transaction';
alter table entries alter column entry_type set not null;
```
