# Hướng dẫn cho agent — Expense Ledger

## Tổng quan

Ứng dụng sổ thu chi cá nhân bằng **Vue 3 + Vite + Supabase**, có thể cài như PWA.

- Tên hiển thị: **DMoney / DMoney**
- Ngôn ngữ giao diện: tiếng Việt
- Giao dịch có `amount` âm là chi, dương là thu.
- Số dư là tổng luỹ kế của tất cả giao dịch theo thời gian, từ cũ đến mới.

## Cấu trúc chính

```text
src/
  App.vue       # Toàn bộ giao diện và logic sổ giao dịch
  supabase.js   # Supabase client và các hàm CRUD giao dịch
  main.js       # Điểm khởi động Vue
  style.css     # Biến màu và CSS toàn cục
supabase_schema.sql  # Schema bảng entries và RLS policy
vite.config.js        # Vite và cấu hình PWA
```

Hiện dự án là ứng dụng nhỏ, chưa tách component. Ưu tiên chỉnh sửa tối thiểu trong `src/App.vue` thay vì tái cấu trúc nếu không cần thiết.

## Lệnh phát triển

```bash
npm install
npm run dev
npm run build
npm run preview
```

Sau thay đổi mã nguồn, chạy `npm run build` để kiểm tra template Vue và production bundle.

## Supabase

Biến môi trường bắt buộc trong `.env`:

```env
VITE_SUPABASE_URL=https://<project>.supabase.co
VITE_SUPABASE_ANON_KEY=<anon-key>
```

Không đưa giá trị thực của các biến này vào mã nguồn, tài liệu công khai hoặc phản hồi.

Schema hiện tại trong `supabase_schema.sql`:

```text
entries
  id          uuid, primary key
  amount      numeric, not null
  note        text, nullable
  created_at  timestamptz, mặc định now()
```

Các hàm truy cập dữ liệu hiện có trong `src/supabase.js`:

- `fetchEntries()` — lấy giao dịch mới nhất trước.
- `addEntry(amount, note)` — thêm giao dịch.
- `deleteEntry(id)` — xoá giao dịch.

RLS hiện cho phép anon đọc/ghi toàn bộ, phù hợp ứng dụng cá nhân một người. Không thay đổi policy hoặc schema nếu không có yêu cầu rõ ràng.

## Hành vi giao diện hiện có

- Thêm giao dịch: nhập số tiền, có thể thêm ghi chú.
- Điều chỉnh số dư: tạo một giao dịch chênh lệch có ghi chú `Điều chỉnh số dư`; không sửa lịch sử cũ.
- Xoá giao dịch: click một dòng mở hộp thoại xác nhận; chỉ xoá khi người dùng chọn **Xoá**.
- Tìm kiếm: theo ghi chú/tên hoặc số tiền; xử lý cả định dạng có dấu phân tách hàng nghìn.
- Màn hình **Hôm nay** là màn hình mặc định, chỉ hiển thị giao dịch của ngày hiện tại theo múi giờ thiết bị, kèm thời gian từng giao dịch và **Số dư ngày** (tổng thu/chi ròng trong ngày).
- Màn hình **Lịch sử** hỗ trợ lọc giao dịch của ngày hiện tại, tuần hiện tại (bắt đầu thứ Hai) hoặc tháng hiện tại; có tìm kiếm và phân trang 10 giao dịch/trang.
- Dù đang tìm kiếm hoặc phân trang, số dư từng dòng vẫn phải được tính từ **toàn bộ** lịch sử, không chỉ các dòng đang hiển thị.

## Quy ước mã nguồn

- Toàn bộ file nguồn là **UTF-8**. Giữ nguyên tiếng Việt có dấu; không gây mojibake.
- Không chỉnh sửa `dist/`, `node_modules/`, `package-lock.json` trừ khi yêu cầu liên quan trực tiếp.
- Không chạy formatter toàn cục hay tự sắp xếp import nếu không được yêu cầu.
- Giao diện sử dụng CSS scoped trong `App.vue`, màu lấy từ CSS variables ở `src/style.css`.
- Giữ phong cách sổ tay hiện tại: nền giấy, màu mực, màu đồng; tránh thêm UI library nếu không được yêu cầu.
- Khi thay đổi cách tải dữ liệu, cần cân nhắc ảnh hưởng đến số dư luỹ kế và phân trang.

## Quy ước commit

- Dùng chuẩn Conventional Commits: `<type>[optional scope]: <description>`.
- `type` được dùng: `fix`, `feat` (hoặc `feature`), `refactor`, `docs`, `style`, `perf`, `vendor`, `chore`, `revert`, `build`, `ci`, `wip`.
- `scope` là tuỳ chọn, là danh từ mô tả phạm vi bị ảnh hưởng, ví dụ: `debt`, `ui`, `auth`, `supabase`.
- Viết `description` ngắn gọn ở thể mệnh lệnh, bắt đầu bằng động từ, viết thường (trừ danh từ riêng) và không kết thúc bằng dấu chấm.
- Với thay đổi không tương thích ngược, thêm `!` ngay sau `type` hoặc `type(scope)`, ví dụ: `refactor!: drop support for Node 6`.
- Không dùng commit message chung chung như `fix bug`, `save code`, `update code` hoặc `create file`.

## Kiểm tra trước khi hoàn tất

1. Xem lại diff, bảo đảm chỉ có thay đổi phục vụ yêu cầu.
2. Xác minh file chỉnh sửa vẫn là UTF-8.
3. Chạy `npm run build`.

## Quy tắc khi push code

Khi người dùng yêu cầu **push code**, agent phải thực hiện đầy đủ các bước sau:

1. Kiểm tra diff và chạy các kiểm tra phù hợp, tối thiểu là `npm run build` nếu có thay đổi mã nguồn.
2. Tạo commit theo quy ước Conventional Commits nếu còn thay đổi chưa commit.
3. Push commit lên remote/branch được yêu cầu.
4. Sau khi push thành công, luôn cung cấp mô tả PR theo đúng format dưới đây, không cần người dùng yêu cầu lại.

### Format mô tả PR bắt buộc

```markdown
## Tiêu đề PR

`<type>(<scope>): <mô tả ngắn gọn>`

## Nội dung PR

### Mô tả

<Mô tả ngắn gọn mục đích của thay đổi>

### Thay đổi

- <Thay đổi 1>
- <Thay đổi 2>

### Kiểm tra

- <Các lệnh kiểm tra đã chạy và kết quả>
```

Tiêu đề và nội dung PR phải bám sát thay đổi thực tế; không bịa đặt các kiểm tra hoặc thay đổi chưa được thực hiện. Nếu không có `scope`, dùng format `<type>: <mô tả ngắn gọn>`.
