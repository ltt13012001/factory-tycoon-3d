# Bản dịch / Translations

Game viết bằng tiếng Việt. Mỗi file ở đây là một ngôn ngữ khác: nó ánh xạ
câu tiếng Việt gốc sang bản dịch. Menu → Ngôn ngữ tự liệt kê mọi file.

```json
{
	"_language": {"code": "fr", "name": "Français", "order": 6},
	"strings": {
		"Tổng quan": "Aperçu",
		"Ngày %d · %s": "Jour %d · %s"
	}
}
```

- `code`: mã ngôn ngữ (fr, de, es, pt_BR, th, id...). `name`: tên ngôn ngữ
  bằng chính nó. `order`: vị trí trong menu.
- Giữ nguyên các chỗ `%d`, `%s`, `%.1f`, `%%`, `{a}`, `{b}`, `\n` **và đúng thứ
  tự của chúng** (Godot không đổi được thứ tự tham số).
- Câu để trống `""` thì game hiện tiếng Việt.

Thêm ngôn ngữ mới:

1. Tạo file `<mã>.json` với `_language` như trên và `"strings": {}`.
2. `python3 tools/i18n_extract.py` thêm mọi câu còn thiếu (để trống) vào mọi
   file; dịch các câu đó. Sau khi sửa code, chạy lại để thêm câu mới;
   `--check` chỉ báo câu còn thiếu.
3. Ngôn ngữ dùng chữ ngoài Latin/Việt (Thái, Ả Rập...) cần thêm font Noto vào
   `tools/subset_fonts.py` và `UiTheme.font()`. Với Trung, Nhật, Hàn, Hindi
   chỉ cần chạy lại `tools/subset_fonts.py` sau khi sửa bản dịch.
4. Kiểm tra: `godot --path . -- --screenshot=/tmp/shots --screenshot-lang --lang=<mã>`
   và `godot --headless --path . --quit-after 3000 -- --smoke-test --smoke-languages`.
