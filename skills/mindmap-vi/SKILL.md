---
name: mindmap-vi
user-invocable: true
description: Sinh sơ đồ tư duy Markmap tương tác từ một file, một URL, text dán vào, hoặc một chủ đề (bản tiếng Việt).
allowed-tools: Bash, Read, Write, Glob, WebFetch
---

# Skill sơ đồ tư duy — sinh Markmap tương tác

## Cách gọi
`/mindmap-vi <đầu-vào> [--panel] [--render] [--output <đường-dẫn>]`

`<đầu-vào>` là một trong:
- **Đường dẫn file** — đọc file đó rồi sinh sơ đồ
- **URL** (`http://` hoặc `https://`) — fetch nội dung trang rồi sinh sơ đồ
- **Text / ghi chú dán vào** — sinh sơ đồ trực tiếp từ đoạn text đó
- Một **chủ đề** ngắn — sinh sơ đồ từ kiến thức của chính model

Tham số:
- `--panel` — thiết kế cấu trúc bằng hội đồng phản biện nhiều agent (tốn nhiều token; dùng cho nguồn phức tạp/quan trọng như paper). Xem **Bước 2 → Hội đồng phản biện**.
- `--render` — sau khi ghi `.md`, sinh thêm một file `.html` độc lập, tương tác được
- `--output <đường-dẫn>` — ghi `.md` vào đường dẫn chỉ định thay vì đường dẫn mặc định

> **Lưu ý đa nền tảng:** Skill này viết theo tên tool của Claude Code (`Read`, `Write`, `Glob`, `Bash`, `WebFetch`). Trên **GitHub Copilot**, dùng tool tương ứng (`view`, `create`, `glob`, `bash`, `web_fetch`) — xem [`references/copilot-tools.md`](references/copilot-tools.md). Workflow giống nhau hoàn toàn trên cả hai nền tảng.

**Toàn bộ output phải viết bằng tiếng Việt** — tiêu đề, nhánh, node. Nếu nguồn đầu vào là tiếng Anh (hoặc ngôn ngữ khác), hãy dịch các khái niệm sang tiếng Việt; giữ nguyên thuật ngữ kỹ thuật đã quen dùng (ví dụ `embedding`, `vector`, `prompt`) khi bản dịch làm mất nghĩa.

## Workflow

### Bước 1: Phân loại đầu vào
Bỏ các tham số ra trước, rồi phân loại phần còn lại và nạp nội dung:

1. Nếu là **URL** (bắt đầu bằng `http://` hoặc `https://`), fetch bằng **WebFetch** (yêu cầu nó trả về phần nội dung chính của trang). Nội dung fetch được chính là nội dung cần xử lý. Kiểm tra điều kiện này **trước** các quy tắc file/text/chủ đề.
2. Nếu không, và là đường dẫn tới một **file đang tồn tại**, đọc bằng Read. Nội dung file chính là nội dung cần xử lý.
3. Nếu không, và là **đoạn text dài hoặc nhiều dòng** (khoảng > 12 từ, hoặc có ký tự xuống dòng), xử lý như **text thô**. Đoạn text đó chính là nội dung.
4. Nếu không, xử lý như một **chủ đề**: sinh nội dung từ kiến thức của chính model.

Dừng lại và hỏi người dùng trong các trường hợp sau (tuyệt đối không tự suy đoán):
- **Fetch URL thất bại** (lỗi mạng, bị chặn, hoặc trang rỗng) → báo tình trạng và hỏi: chuyển sang sinh sơ đồ từ kiến thức sẵn có về chủ đề của trang đó, hay đổi URL khác? Không bịa nội dung trang.
- **Trông giống đường dẫn file** (kết thúc bằng `.md`/`.txt`, hoặc chứa `/` hay `\`) nhưng **file không tồn tại** → báo `Không tìm thấy file: <đường-dẫn>`, và hỏi: chuyển sang sinh theo chủ đề, hay sửa lại đường dẫn?
- Đầu vào **rỗng hoặc chỉ có khoảng trắng** → đề nghị người dùng cung cấp nội dung hoặc chủ đề.
- Đầu vào **thực sự nhập nhằng** (một cụm từ có thể là text, cũng có thể là chủ đề) → mặc định coi là **chủ đề**, và nói rõ giả định đó trong một câu để người dùng chỉnh lại nếu cần.

### Bước 2: Dựng cây phân cấp (chiến lược hỗn hợp)
Biến nội dung thành một cây node:

- Nếu nội dung **đã có cấu trúc sẵn** (heading rõ ràng / outline dạng bullet): tận dụng outline đó, nhưng **nén mỗi node thành một cụm từ ngắn** (≤ khoảng 8 từ). Không copy nguyên câu.
- Nếu nội dung là text **không có cấu trúc** hoặc là một **chủ đề**: rút ra các khái niệm chính, gom thành **4–7 nhánh chính**, mỗi nhánh có các điểm con súc tích.

Quy tắc:
- **Độ sâu:** hướng tới 3–4 tầng.
- **Dùng cụm từ, không dùng câu:** mỗi node là một nhãn ngắn.
- **Dễ đọc quan trọng hơn đầy đủ:** với nguồn rất dài, hãy map cấu trúc và các ý chính — không phải từng dòng. Với nguồn không cấu trúc / chủ đề / nguồn lớn, hướng tới **4–7 nhánh chính**; khi nguồn đã có cấu trúc thì theo outline của chính nó. Mạnh tay lược bỏ.

#### Hội đồng phản biện (chỉ khi có `--panel`)
Khi có `--panel`, đừng tự dựng cấu trúc một mình. Hãy chạy một hội đồng nhiều
agent qua tool **Workflow**, dùng các prompt trong
[`references/judge-panel.md`](references/judge-panel.md):

1. **Propose** — 3 agent proposer, mỗi agent thiết kế một cấu trúc hoàn chỉnh
   theo một lăng kính khác nhau (ưu tiên mạch truyện, ưu tiên dữ liệu, ưu tiên
   người xem), gán cho mọi node một **format** (list/table/code/checkbox/link/bold)
   và một **tier** (`core` render được ở mọi nơi; `rich` = table/code/checkbox,
   chỉ markmap chuẩn).
2. **Judge** — 3 agent judge cho điểm độc lập tất cả phương án theo rubric (quy
   tắc skill + trình bày: punchline-first, con số chủ đạo, node lá dễ đọc, cân
   đối thị giác, format phù hợp, và **node phải bằng tiếng Việt**), rồi nêu ý
   hay nhất của từng phương án.
3. **Synthesize** — 1 agent synthesizer lấy phương án điểm cao nhất làm xương
   sống, ghép thêm các ý mà hội đồng đã đánh dấu, rồi xuất ra file Markmap `.md`
   cuối cùng.

Dùng đúng khung Workflow và đúng các prompt/schema trong file reference đó. Lưu ý
chi phí: nó spawn khoảng 7 agent và tốn nhiều token — chỉ dùng cho nguồn phức tạp
hoặc quan trọng. Nếu cả 3 proposer đều thất bại, quay về cách dựng một lượt ở
Bước 2 và nói rõ với người dùng.

**An toàn render-tier:** synthesizer giữ nguyên các format `rich` — chúng render
được trên đường `.md` mặc định (markmap.js.org / extension VS Code / `--render`).
Đường **poster dọc** (`scripts/parse-md.mjs`) chỉ đọc heading `##` và bullet `-`,
nên trước khi đưa một file `.md` từ panel xuống đường poster, hãy cho nó qua
`scripts/degrade-rich.mjs` (`node scripts/degrade-rich.mjs <in.md> <out.md>`) —
script này viết lại table/code/checkbox thành bullet. Nội dung bị đổi hình, **không
bao giờ bị âm thầm bỏ mất**.

### Bước 3: Ghi file Markmap `.md`
Ghi file theo đúng style ở mục **Định dạng Markmap** bên dưới.

Đường dẫn output:
- Đầu vào là file `foo.md` → `foo.mindmap.md` (cùng thư mục).
- Đầu vào là URL → lấy slug từ tiêu đề trang (hoặc segment cuối của URL) → `<slug>.mindmap.md` trong thư mục hiện tại.
- Đầu vào là text → lấy slug từ tiêu đề H1 của sơ đồ → `<slug>.mindmap.md` trong thư mục hiện tại (quy tắc slug giống chủ đề).
- Đầu vào là chủ đề → `<slug-chủ-đề>.mindmap.md` trong thư mục hiện tại (slug = chữ thường, khoảng trắng → `-`, bỏ dấu tiếng Việt).
- `--output <đường-dẫn>` ghi đè đường dẫn mặc định, dùng đúng giá trị được cho.
- **Trước khi ghi, dùng Glob kiểm tra file đích đã tồn tại chưa.** Nếu đã tồn tại, chèn số đếm trước `.mindmap.md` — `<tên>-2.mindmap.md`, rồi `<tên>-3.mindmap.md`… lấy tên đầu tiên còn trống. Đường dẫn `--output` tường minh cũng áp dụng quy tắc hậu tố này. **Tuyệt đối không ghi đè im lặng lên file có sẵn.**

Sau khi ghi, cho người dùng biết đường dẫn chính xác và cách xem: mở tại https://markmap.js.org, hoặc dùng extension "Markmap" của VS Code.

### Bước 4 (chỉ khi có `--render`): render ra HTML
`render.sh` nằm trong thư mục `scripts/` cùng cấp với SKILL.md này. Nếu chưa biết đường dẫn tuyệt đối của nó, dùng Glob để tìm (`**/skills/mindmap-vi/scripts/render.sh`), rồi chạy theo đường dẫn đó:

```
bash <skill-dir>/scripts/render.sh "<output.md>"
```

- Khi thành công, nó in đường dẫn `.html` ra stdout — hãy báo lại cho người dùng.
- Nếu trả về mã khác 0 (ví dụ chưa cài `npx`, exit code 3), file `.md` vẫn là kết quả được đảm bảo. Nói với người dùng là đã bỏ qua bước render, và hiển thị câu lệnh chạy tay mà nó in ra (trường hợp thiếu npx với exit code 3 sẽ in một câu lệnh như vậy). **Không** coi đây là thất bại của cả task.
- Tên tab browser của trang đã render lấy từ `title:` trong frontmatter (không có thì lấy H1), nên luôn ghi `title:` cho đúng nội dung — nếu không thì mọi map mở ra đều hiện `Markmap`.

## Định dạng Markmap
Ghi file `.md` theo style sau:

```
---
title: <Tiêu đề sơ đồ>
markmap:
  colorFreezeLevel: 2
  maxWidth: 300
---

# <Chủ đề trung tâm>

## <Nhánh 1>
- <Điểm chính>
  - <Điểm con>
- <Điểm chính>

## <Nhánh 2>
- <Điểm chính>
```

- Có **đúng một heading `#` cấp 1** — node gốc / chủ đề trung tâm.
- Heading `##` = nhánh chính; `###` và các list item `-` = các tầng sâu hơn.
- Markdown inline (`**in đậm**`, `` `code` ``, link) được phép và sẽ giữ nguyên.
- Giữ nguyên giá trị mặc định trong frontmatter (`colorFreezeLevel: 2`, `maxWidth: 300`).

## Ví dụ minh hoạ
Đầu vào (một đoạn có cấu trúc):

> # Retrieval-Augmented Generation (RAG)
> ## Indexing
> Chunk documents, embed them, store vectors.
> ## Retrieval
> Embed the query, find nearest-neighbour chunks.
> ## Generation
> Inject retrieved context into the prompt.

Output `retrieval-augmented-generation.mindmap.md`:

```
---
title: Retrieval-Augmented Generation (RAG)
markmap:
  colorFreezeLevel: 2
  maxWidth: 300
---

# Retrieval-Augmented Generation (RAG)

## Lập chỉ mục
- Chia nhỏ tài liệu
- Tạo embedding cho từng đoạn
- Lưu vector

## Truy hồi
- Tạo embedding cho câu truy vấn
- Tìm các đoạn gần nhất

## Sinh câu trả lời
- Chèn ngữ cảnh vào prompt
```

## Ghi chú
- Luồng mặc định **không cần dependency** nào (chỉ dùng Read/Write; đầu vào URL thì thêm WebFetch).
- `--render` cần Node.js / `npx` (dùng `npx markmap-cli`, không cần cài global).
