## Number formatting for the UI: Vietnamese style ("$1.234,50") in
## Vietnamese, international style ("$1,234.50") in every other language.
class_name Fmt
extends RefCounted


static func money(cents: int) -> String:
	var negative := cents < 0
	var c := absi(cents)
	var text := group(c / 100)
	if c % 100 != 0:
		text += decimal_mark() + "%02d" % (c % 100)
	return ("-$" if negative else "$") + text


## Short money for tight spots such as the top bar: whole dollars below a
## million, then "triệu" / "tỷ" with up to two decimals ("$1,23 tr",
## "-$45,6 tỷ"), so the text stays short however rich the player gets.
static func money_short(cents: int) -> String:
	var dollars := absi(cents) / 100
	var sign := "-$" if cents < 0 else "$"
	var units := [[1000000000000, "nghìn tỷ"], [1000000000, "tỷ"], [1000000, "tr"]]
	if not is_vietnamese():
		units = [[1000000000000, "T"], [1000000000, "B"], [1000000, "M"]]
	for u in units:
		var unit: int = u[0]
		if dollars < unit:
			continue
		var whole := dollars / unit
		var decimals := 2 if whole < 10 else (1 if whole < 100 else 0)
		var text := group(whole)
		if decimals > 0:
			var frac := str((dollars % unit) * (10 ** decimals) / unit).pad_zeros(decimals).rstrip("0")
			if frac != "":
				text += decimal_mark() + frac
		return "%s%s%s%s" % [sign, text, " " if is_vietnamese() else "", u[1]]
	return sign + group(dollars)


static func group(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var count := 0
	var sep := "." if is_vietnamese() else ","
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = sep + out
	return ("-" if n < 0 else "") + out


static func clock(tick: int, cfg: EconomyConfig) -> String:
	var minute := ((tick % cfg.ticks_per_day) * 1440 / cfg.ticks_per_day + cfg.day_start_hour * 60) % 1440
	return "%02d:%02d" % [minute / 60, minute % 60]


static func is_vietnamese() -> bool:
	return TranslationServer.get_locale().begins_with("vi")


static func decimal_mark() -> String:
	return "," if is_vietnamese() else "."
