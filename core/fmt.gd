## Vietnamese-style number formatting for the UI ("$1.234,50").
class_name Fmt
extends RefCounted


static func money(cents: int) -> String:
	var negative := cents < 0
	var c := absi(cents)
	var text := group(c / 100)
	if c % 100 != 0:
		text += ",%02d" % (c % 100)
	return ("-$" if negative else "$") + text


static func group(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out


static func clock(tick: int, cfg: EconomyConfig) -> String:
	var minute := ((tick % cfg.ticks_per_day) * 1440 / cfg.ticks_per_day + cfg.day_start_hour * 60) % 1440
	return "%02d:%02d" % [minute / 60, minute % 60]
