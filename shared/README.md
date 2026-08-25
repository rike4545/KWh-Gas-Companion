# Shared discount links

Edit `discount_links.json` when discount, coupon, affiliate, or referral links change.

Then run this from the `KWh Gas Companion` folder:

```sh
python3 scripts/sync_discount_links.py
```

The sync updates the iOS `DiscountsView.swift` list and the Android `ToolDetailScreen.kt` discount hub list from the same source.
