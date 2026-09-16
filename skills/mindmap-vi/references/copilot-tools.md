# Bảng map tên tool cho GitHub Copilot

Skill này được viết theo tên tool của Claude Code. GitHub Copilot cung cấp cùng những năng lực đó nhưng với tên khác.
Khi trong skill xuất hiện tool ở cột bên trái, hãy dùng tool Copilot tương ứng ở cột bên phải.

| Cách viết trong skill (Claude Code) | Tool Copilot tương ứng |
|-------------------------------------|------------------------|
| `Read` (đọc file)                   | `view`                 |
| `Write` (tạo file)                  | `create`               |
| `Edit` (sửa file)                   | `edit`                 |
| `Bash` (chạy câu lệnh)              | `bash`                 |
| `Glob` (tìm theo tên file)          | `glob`                 |
| `WebFetch` (fetch URL)              | `web_fetch`            |

Mọi phần còn lại của skill (workflow, định dạng Markmap, `render.sh`) không phụ thuộc nền tảng và hoạt động giống nhau trên cả hai.

## Lưu ý riêng cho Copilot

- **Bước `--render`:** skill gọi `bash <skill-dir>/scripts/render.sh`. Trên Copilot đó là tool `bash` — cùng câu lệnh, cùng hành vi.
- **Đầu vào URL:** skill dùng `WebFetch` để fetch URL; trên Copilot tương ứng là `web_fetch`.
- **Kiểm tra trùng tên trước khi ghi:** skill dùng `Glob`; trên Copilot tương ứng là `glob`.
