## A source of rewarded video ads. Subclasses talk to an ad network; the
## Monetization autoload picks one when the game starts.
class_name AdsBackend
extends Node

## Shown in the interface next to the ad buttons when not "".
var label := ""


## True when this platform can show ads at all.
func available() -> bool:
	return false


## True when an ad is loaded and can be shown right now.
func is_ready() -> bool:
	return false


## Shows one rewarded ad; done(rewarded: bool) runs once it closes.
## rewarded is true only when the network says the ad was watched to the end.
func show_rewarded(done: Callable) -> void:
	done.call(false)
