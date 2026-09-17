# Hội đồng phản biện — prompt, schema và workflow

File này chỉ được nạp khi `/mindmap-vi` được gọi kèm `--panel`. Nó định nghĩa hội
đồng nhiều agent chịu trách nhiệm thiết kế cấu trúc sơ đồ và format của từng
node. Các prompt bên dưới **chính là hệ thống** — dùng nguyên văn (chỉ nội suy
phần nội dung nguồn); không diễn giải lại.

**Toàn bộ node của sơ đồ cuối cùng phải viết bằng tiếng Việt**, kể cả khi nguồn
là tiếng Anh — giống ràng buộc ở đầu SKILL.md. Ràng buộc này đã nằm trong khối
context dùng chung bên dưới, nên cả proposer và synthesizer đều thấy.

## Khối context dùng chung

Ghép khối này vào đầu prompt của mọi proposer và của synthesizer:

```
NỘI DUNG NGUỒN:
<toàn bộ nội dung đầu vào đã resolve>

NGÔN NGỮ (ràng buộc cứng):
- Mọi node — tiêu đề, nhánh, điểm con — phải viết bằng tiếng Việt.
- Nguồn tiếng Anh thì dịch khái niệm sang tiếng Việt; giữ nguyên thuật ngữ kỹ
  thuật đã quen dùng (`embedding`, `vector`, `prompt`) khi dịch làm mất nghĩa.

QUY TẮC SKILL (ràng buộc cứng):
- Đúng một H1 (chủ đề trung tâm).
- 4–7 nhánh chính (`##` H2).
- Tổng độ sâu 3–4 tầng.
- Mỗi node là một cụm từ ngắn (≤ khoảng 8 từ), không bao giờ là một câu.
- Mạnh tay lược bỏ; dễ đọc quan trọng hơn đầy đủ.
- Khi nguồn đã có cấu trúc, đi theo outline của chính nó.

FORMAT TỪNG NODE — gán cho mỗi node một format và một render tier:
- bullet list  (core)  — các dữ kiện song song
- table        (rich)  — so sánh / số liệu benchmark
- code block   (rich)  — công thức, hàm reward, code
- checkbox     (rich)  — task, hạn chế, checklist
- link         (core)  — tài liệu tham khảo, repo, arXiv
- bold inline  (core)  — nhấn mạnh / con số chủ đạo
"core" render được trên mọi đường; "rich" chỉ render trong markmap chuẩn.
```

## Prompt cho proposer (×3 — mỗi agent một lăng kính)

Mỗi proposer nhận khối dùng chung, cộng MỘT chỉ thị lăng kính, rồi tới câu chốt chung.

- **Proposer A — ưu tiên mạch truyện:** "Thiết kế sơ đồ bằng cách phản chiếu mạch
  và outline của chính nguồn. Đi theo trật tự tự nhiên của tài liệu; mỗi nhánh
  chính tương ứng một phần lớn của nguồn. Giữ nguyên dòng logic của tác giả."
- **Proposer B — ưu tiên dữ liệu:** "Thiết kế sơ đồ xoay quanh các con số chủ đạo
  và bằng chứng. Mở đầu bằng kết quả định lượng mạnh nhất; gom node sao cho các
  số liệu then chốt và luận điểm chúng chống đỡ nằm ngay trung tâm. In đậm mọi
  con số chủ đạo."
- **Proposer C — ưu tiên người xem:** "Thiết kế sơ đồ để TRÌNH BÀY cho khán giả
  qua máy chiếu. Đặt punchline lên trước — ý quan trọng nhất là nhánh 1. Tối ưu
  từng node lá để đọc được trong một cái nhìn; cắt thẳng tay bất cứ gì không đọc
  rõ trên slide."

Câu chốt chung (cho cả ba): "Trả về một cấu trúc hoàn chỉnh: H1, 4–7 nhánh, node
lồng nhau sâu 3–4 tầng, và với mỗi node là text (tiếng Việt), format, render
tier. Không viết markdown cuối cùng — chỉ trả về dữ liệu có cấu trúc."

## Prompt cho judge (×3 — giống nhau, chạy độc lập)

"Bạn đang cho điểm 3 cấu trúc sơ đồ ứng viên của cùng một nguồn. Cho điểm 1–5
cho TỪNG phương án trên mọi tiêu chí dưới đây. Hãy là người phản biện khắt khe,
độc lập; đừng mặc định là các phương án đều tốt.

Tiêu chí: số nhánh (4–7), độ sâu (3–4 tầng), cách diễn đạt (cụm từ, không phải
câu), độ dễ đọc (đã nén), trung thực với nguồn (phản chiếu nguồn có cấu trúc),
punchline-first (ý chốt được đưa lên sớm), con số chủ đạo (số lớn được in đậm),
node lá dễ đọc (đọc được khi trình chiếu), cân đối thị giác (các nhánh tương
đương nhau), format phù hợp (đúng format cho từng node), tiếng Việt (mọi node
viết bằng tiếng Việt, thuật ngữ kỹ thuật giữ nguyên hợp lý).

Với mỗi phương án, hãy nêu MỘT ý hay nhất mà nó đóng góp — một nhánh, một cách
khung hoá, hay một node mà phương án thắng nên lấy. Trả về điểm + ý hay nhất của
từng phương án dưới dạng dữ liệu có cấu trúc. Khi còn nghi ngờ, cho điểm thấp."

## Prompt cho synthesizer (×1)

"Bạn nhận 3 cấu trúc sơ đồ ứng viên và 3 bảng điểm của hội đồng. Lấy phương án
có tổng điểm cao nhất làm XƯƠNG SỐNG. Sau đó ghép vào các ý hay nhất mà hội đồng
đã đánh dấu từ hai phương án còn lại, ở bất cứ chỗ nào chúng làm xương sống mạnh
hơn mà không phá giới hạn 4–7 nhánh / 3–4 tầng. Xử lý xung đột format theo bảng
format từng node.

Xuất ra file Markmap `.md` CUỐI CÙNG: frontmatter (`colorFreezeLevel: 2`,
`maxWidth: 300`), một H1, các nhánh và node đã chọn, mỗi node theo đúng format
của nó. Với node gắn tier 'rich', đây là output đường chuẩn — giữ nguyên format
rich. Mọi node phải viết bằng tiếng Việt. Trả về markdown hoàn chỉnh."

## Schema output (áp qua option `schema` của Workflow)

- **Proposer** → `{ title, branches: [{ heading, nodes: [{ text, format, tier, children: [...] }] }] }`
  với `format` ∈ `list|table|code|checkbox|link|bold`, `tier` ∈ `core|rich`.
- **Judge** → `{ scores: [{ proposalId, dimensions: { branchCount, depth, phrasing, legibility, sourceFidelity, punchlineFirst, headlineNumbers, leafLegibility, visualBalance, formatFit, vietnamese }, total }], bestIdeas: [{ proposalId, idea }] }`
- **Synthesizer** → trả về file Markmap `.md` cuối cùng dưới dạng text (không phải JSON).

## Khung workflow (chỉnh inline khi có `--panel`)

```js
export const meta = {
  name: 'mindmap-vi-judge-panel',
  description: 'Hội đồng thiết kế cấu trúc sơ đồ: đề xuất, phản biện, tổng hợp',
  phases: [{ title: 'Propose' }, { title: 'Judge' }, { title: 'Synthesize' }],
}

const SHARED = `...khối context dùng chung, đã nội suy NỘI DUNG NGUỒN...`
const LENSES = [
  { id: 'A', label: 'mạch truyện',  directive: '...' },
  { id: 'B', label: 'dữ liệu',      directive: '...' },
  { id: 'C', label: 'người xem',    directive: '...' },
]

phase('Propose')
const proposals = (await parallel(LENSES.map(l => () =>
  agent(`${SHARED}\n\nLĂNG KÍNH: ${l.directive}\n\nCHỐT: chỉ trả về dữ liệu có cấu trúc.`,
    { label: `propose:${l.id}`, phase: 'Propose', schema: PROPOSAL_SCHEMA })
))).filter(Boolean)

phase('Judge')
const scorecards = (await parallel([1,2,3].map(n => () =>
  agent(`${JUDGE_PROMPT}\n\nPHƯƠNG ÁN:\n${JSON.stringify(proposals)}`,
    { label: `judge:${n}`, phase: 'Judge', schema: JUDGE_SCHEMA })
))).filter(Boolean)

phase('Synthesize')
const finalMd = await agent(
  `${SYNTH_PROMPT}\n\nPHƯƠNG ÁN:\n${JSON.stringify(proposals)}\n\nĐIỂM:\n${JSON.stringify(scorecards)}`,
  { label: 'synthesize', phase: 'Synthesize' })

return { finalMd }
```

Sau khi workflow trả về `finalMd`, skill ghi nó ra file `.md` (Bước 3). Chỉ với
đường **poster dọc**, hãy đưa nó qua `scripts/degrade-rich.mjs` trước để
table/code/checkbox biến thành bullet mà parser poster đọc được (markmap chuẩn
giữ nguyên format rich).
