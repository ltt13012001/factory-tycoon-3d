## Settings for ads and in-app purchases. Change the ad unit ids to your own
## from the AdMob console before publishing (see docs/monetization.md); the
## ids below are Google's public test ads, which never pay.
class_name MonetizationConfig
extends RefCounted

## Rewarded ad units (AdMob → Apps → Ad units → Rewarded).
const ADMOB_REWARDED_IOS := "ca-app-pub-3940256099942544/1712485313"
const ADMOB_REWARDED_ANDROID := "ca-app-pub-3940256099942544/5224354917"
## Ask for non-personalised ads. The game then never tracks players across
## apps, so iOS needs no App Tracking Transparency prompt. Ads pay somewhat
## less; switch off only together with an ATT prompt (docs/monetization.md).
const NON_PERSONALIZED_ADS := true
## Seconds between two ads, so nobody watches ads back to back by mistake.
const AD_COOLDOWN_SECONDS := 20.0

## Store product id = PRODUCT_PREFIX + pack id (DiamondManager.PACKS), e.g.
## com.ltt13012001.factorytycoon3d.diamonds_small. Create exactly these as
## consumable products in App Store Connect and Google Play Console.
const PRODUCT_PREFIX := "com.ltt13012001.factorytycoon3d."


static func product_id(pack_id: String) -> String:
	return PRODUCT_PREFIX + pack_id


static func pack_id(product_id: String) -> String:
	return product_id.trim_prefix(PRODUCT_PREFIX)
