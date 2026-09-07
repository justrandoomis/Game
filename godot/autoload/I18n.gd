extends Node
## Localisation.
##
## English, Arabic and Kurdish (Sorani), matching the languages the Levonis
## platform already ships. Arabic and Kurdish set the UI to right-to-left.
##
## The farm itself is never mirrored: the isometric geometry, the grid and the
## station layout stay exactly as they are in every language. Only text and UI
## flow adapt — mirroring the scene would break the one fixed perspective the
## whole art direction depends on.

signal language_changed(lang: String)

const LANGS := ["en", "ar", "ku"]
const RTL_LANGS := ["ar", "ku"]

var lang: String = "en"

const STRINGS := {
	"en": {
		"app_title": "Printer Farm",
		"farm": "Farm", "orders": "Orders", "shop": "Shop",
		"inventory": "Inventory", "upgrades": "Upgrades",
		"level": "Level", "coins": "Coins", "reputation": "Reputation",
		"workshop_value": "Workshop Value",
		"idle": "Idle", "printing": "Printing", "paused": "Paused",
		"maintenance": "Maintenance", "failed": "Print failed", "offline": "Offline",
		"empty_station": "Add Station", "locked": "Locked",
		"unlock_station": "Unlock Station", "required_level": "Required level",
		"cost": "Cost", "capacity": "Workshop capacity",
		"expand_workshop": "Expand Workshop", "expand_hint": "Move to a bigger space",
		"customer_orders": "Customer Orders", "accept": "Accept", "reject": "Reject",
		"deliver": "Deliver", "ready": "Ready to deliver", "in_progress": "In progress",
		"queued": "Queued", "waiting": "Waiting", "assign": "Assign printers",
		"start_printing": "Start printing", "deadline": "Deadline", "reward": "Reward",
		"material": "Material", "color": "Colour", "quantity": "Quantity",
		"print_time": "Print time", "difficulty": "Difficulty", "customer": "Customer",
		"urgent": "URGENT", "overdue": "Overdue", "no_orders": "No orders right now",
		"no_orders_hint": "New requests arrive regularly. Keep your printers busy.",
		"remaining": "Remaining", "health": "Health", "queue": "Queue",
		"view_job": "View job", "service": "Service", "repair": "Repair",
		"clear": "Clear plate", "cancel": "Cancel", "close": "Close",
		"buy": "Buy", "buy_filament": "Buy filament", "buy_printer": "Buy printer",
		"sell": "Sell", "install": "Install", "installed": "Installed",
		"print_more": "Print more", "stock": "Stock", "demand": "Demand",
		"sale_price": "Sale price", "production_cost": "Cost",
		"spools": "Spools", "parts": "Spare parts", "printers": "Printers",
		"missing": "Missing", "available": "Available", "required": "Required",
		"not_enough_coins": "Not enough coins",
		"not_enough_filament": "Not enough filament",
		"level_too_low": "Reach a higher level first",
		"queue_full": "That printer's queue is full",
		"printer_busy": "That printer is busy",
		"too_many_orders": "You already have your hands full",
		"order_expired": "That order is no longer available",
		"slot_occupied": "There is already a printer there",
		"workshop_full": "This workshop is full — expand it",
		"fill_current_room": "Fill every station here first",
		"while_away": "While you were away",
		"prints_done": "prints completed", "orders_delivered": "orders delivered",
		"coins_earned": "coins earned", "needs_service": "printers need a service",
		"level_up": "Level %d", "new_unlock": "Unlocked",
		"unlocks_at": "Unlocks at level %d",
		"tutorial_1": "This is your workshop. Tap your printer to see what it is doing.",
		"tutorial_2": "A customer is waiting. Open Orders and accept the job.",
		"tutorial_3": "Pick a printer and start the print.",
		"tutorial_4": "Your print is running. Come back when it is done.",
		"settings": "Settings", "sound": "Sound", "language": "Language",
		"on": "On", "off": "Off", "loading": "Loading your workshop…",
		"connection_error": "Cannot reach the workshop. Check your connection.",
		"retry": "Retry", "eta": "Ready in", "per_unit": "each",
		"stations": "Stations", "grams": "g", "hours": "h",
	},
	"ar": {
		"app_title": "مزرعة الطباعة",
		"farm": "المزرعة", "orders": "الطلبات", "shop": "المتجر",
		"inventory": "المخزون", "upgrades": "التطويرات",
		"level": "المستوى", "coins": "العملات", "reputation": "السمعة",
		"workshop_value": "قيمة الورشة",
		"idle": "متوقفة", "printing": "تطبع", "paused": "موقوفة مؤقتًا",
		"maintenance": "صيانة", "failed": "فشلت الطباعة", "offline": "غير متصلة",
		"empty_station": "إضافة محطة", "locked": "مقفلة",
		"unlock_station": "فتح محطة", "required_level": "المستوى المطلوب",
		"cost": "التكلفة", "capacity": "سعة الورشة",
		"expand_workshop": "توسيع الورشة", "expand_hint": "انتقل إلى مساحة أكبر",
		"customer_orders": "طلبات الزبائن", "accept": "قبول", "reject": "رفض",
		"deliver": "تسليم", "ready": "جاهز للتسليم", "in_progress": "قيد التنفيذ",
		"queued": "في الانتظار", "waiting": "بالانتظار", "assign": "توزيع الطابعات",
		"start_printing": "ابدأ الطباعة", "deadline": "الموعد النهائي", "reward": "المكافأة",
		"material": "المادة", "color": "اللون", "quantity": "الكمية",
		"print_time": "زمن الطباعة", "difficulty": "الصعوبة", "customer": "الزبون",
		"urgent": "عاجل", "overdue": "متأخر", "no_orders": "لا توجد طلبات حاليًا",
		"no_orders_hint": "تصل طلبات جديدة باستمرار. أبقِ طابعاتك مشغولة.",
		"remaining": "المتبقي", "health": "الحالة", "queue": "قائمة الانتظار",
		"view_job": "عرض المهمة", "service": "صيانة", "repair": "إصلاح",
		"clear": "تنظيف المنصة", "cancel": "إلغاء", "close": "إغلاق",
		"buy": "شراء", "buy_filament": "شراء فتيل", "buy_printer": "شراء طابعة",
		"sell": "بيع", "install": "تركيب", "installed": "مركّب",
		"print_more": "اطبع المزيد", "stock": "المخزون", "demand": "الطلب",
		"sale_price": "سعر البيع", "production_cost": "الكلفة",
		"spools": "البكرات", "parts": "قطع الغيار", "printers": "الطابعات",
		"missing": "ناقص", "available": "متوفر", "required": "مطلوب",
		"not_enough_coins": "العملات غير كافية",
		"not_enough_filament": "الفتيل غير كافٍ",
		"level_too_low": "تحتاج مستوى أعلى",
		"queue_full": "قائمة انتظار الطابعة ممتلئة",
		"printer_busy": "الطابعة مشغولة",
		"too_many_orders": "لديك طلبات كثيرة بالفعل",
		"order_expired": "لم يعد هذا الطلب متاحًا",
		"slot_occupied": "توجد طابعة هنا بالفعل",
		"workshop_full": "الورشة ممتلئة — وسّعها",
		"fill_current_room": "املأ كل المحطات هنا أولًا",
		"while_away": "أثناء غيابك",
		"prints_done": "طباعات مكتملة", "orders_delivered": "طلبات مُسلّمة",
		"coins_earned": "عملات مكتسبة", "needs_service": "طابعات تحتاج صيانة",
		"level_up": "المستوى %d", "new_unlock": "تم الفتح",
		"unlocks_at": "يُفتح عند المستوى %d",
		"tutorial_1": "هذه ورشتك. المس الطابعة لترى ما تفعله.",
		"tutorial_2": "هناك زبون ينتظر. افتح الطلبات واقبل المهمة.",
		"tutorial_3": "اختر طابعة وابدأ الطباعة.",
		"tutorial_4": "الطباعة جارية. عُد عند انتهائها.",
		"settings": "الإعدادات", "sound": "الصوت", "language": "اللغة",
		"on": "تشغيل", "off": "إيقاف", "loading": "جارٍ تحميل ورشتك…",
		"connection_error": "تعذّر الوصول إلى الورشة. تحقق من اتصالك.",
		"retry": "إعادة المحاولة", "eta": "جاهز خلال", "per_unit": "للقطعة",
		"stations": "المحطات", "grams": "غ", "hours": "س",
	},
	"ku": {
		"app_title": "کێڵگەی چاپکردن",
		"farm": "کێڵگە", "orders": "داواکاریەکان", "shop": "فرۆشگا",
		"inventory": "کۆگا", "upgrades": "بەرزکردنەوە",
		"level": "ئاست", "coins": "دراوەکان", "reputation": "ناوبانگ",
		"workshop_value": "بەهای وۆرکشۆپ",
		"idle": "چالاک نییە", "printing": "چاپ دەکات", "paused": "وەستێنراوە",
		"maintenance": "چاککردن", "failed": "چاپکردن سەرکەوتوو نەبوو", "offline": "دەرهێڵ",
		"empty_station": "زیادکردنی وێستگە", "locked": "داخراو",
		"unlock_station": "کردنەوەی وێستگە", "required_level": "ئاستی پێویست",
		"cost": "تێچوو", "capacity": "توانای وۆرکشۆپ",
		"expand_workshop": "فراوانکردنی وۆرکشۆپ", "expand_hint": "بڕۆ بۆ شوێنێکی گەورەتر",
		"customer_orders": "داواکاری کڕیاران", "accept": "قبوڵکردن", "reject": "ڕەتکردنەوە",
		"deliver": "گەیاندن", "ready": "ئامادەیە بۆ گەیاندن", "in_progress": "لە جێبەجێکردندا",
		"queued": "لە ڕیزدا", "waiting": "چاوەڕوانە", "assign": "دابەشکردنی چاپکەرەکان",
		"start_printing": "دەستپێکردنی چاپ", "deadline": "کۆتا کات", "reward": "خەڵات",
		"material": "ماددە", "color": "ڕەنگ", "quantity": "بڕ",
		"print_time": "کاتی چاپ", "difficulty": "سەختی", "customer": "کڕیار",
		"urgent": "بەپەلە", "overdue": "دواکەوتوو", "no_orders": "ئێستا داواکاری نییە",
		"no_orders_hint": "داواکاری نوێ بەردەوام دێت. چاپکەرەکانت سەرقاڵ ڕابگرە.",
		"remaining": "ماوە", "health": "دۆخ", "queue": "ڕیز",
		"view_job": "بینینی ئەرک", "service": "چاککردن", "repair": "چاککردنەوە",
		"clear": "پاککردنەوەی پلێت", "cancel": "پاشگەزبوونەوە", "close": "داخستن",
		"buy": "کڕین", "buy_filament": "کڕینی فیلامێنت", "buy_printer": "کڕینی چاپکەر",
		"sell": "فرۆشتن", "install": "دانان", "installed": "دانراوە",
		"print_more": "زیاتر چاپ بکە", "stock": "کۆگا", "demand": "داواکاری",
		"sale_price": "نرخی فرۆشتن", "production_cost": "تێچوو",
		"spools": "بۆبینەکان", "parts": "پارچە یەدەکەکان", "printers": "چاپکەرەکان",
		"missing": "کەمە", "available": "بەردەستە", "required": "پێویستە",
		"not_enough_coins": "دراو بەس نییە",
		"not_enough_filament": "فیلامێنت بەس نییە",
		"level_too_low": "پێویستت بە ئاستێکی بەرزترە",
		"queue_full": "ڕیزی چاپکەر پڕە",
		"printer_busy": "چاپکەر سەرقاڵە",
		"too_many_orders": "داواکاری زۆرت هەیە",
		"order_expired": "ئەم داواکاریە چیتر بەردەست نییە",
		"slot_occupied": "چاپکەرێک لێرەیە",
		"workshop_full": "وۆرکشۆپ پڕە — فراوانی بکە",
		"fill_current_room": "سەرەتا هەموو وێستگەکان پڕ بکە",
		"while_away": "لە کاتی نەبوونتدا",
		"prints_done": "چاپی تەواوبوو", "orders_delivered": "داواکاری گەیەنراو",
		"coins_earned": "دراوی بەدەستهاتوو", "needs_service": "چاپکەر پێویستی بە چاککردنە",
		"level_up": "ئاست %d", "new_unlock": "کرایەوە",
		"unlocks_at": "لە ئاستی %d دەکرێتەوە",
		"tutorial_1": "ئەمە وۆرکشۆپەکەتە. دەست لە چاپکەر بدە بۆ بینینی کارەکەی.",
		"tutorial_2": "کڕیارێک چاوەڕوانە. داواکاریەکان بکەرەوە و ئەرکەکە قبوڵ بکە.",
		"tutorial_3": "چاپکەرێک هەڵبژێرە و چاپ دەست پێ بکە.",
		"tutorial_4": "چاپکردن بەردەوامە. کاتێک تەواو بوو بگەڕێوە.",
		"settings": "ڕێکخستن", "sound": "دەنگ", "language": "زمان",
		"on": "کارا", "off": "ناکارا", "loading": "وۆرکشۆپەکەت باردەکرێت…",
		"connection_error": "ناتوانرێت پەیوەندی بە وۆرکشۆپەوە بکرێت.",
		"retry": "دووبارە هەوڵبدە", "eta": "ئامادە دەبێت لە", "per_unit": "بۆ هەر دانەیەک",
		"stations": "وێستگەکان", "grams": "گ", "hours": "کات",
	},
}


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		set_language(String(cfg.get_value("i18n", "lang", _device_language())))
	else:
		set_language(_device_language())


func _device_language() -> String:
	var code := OS.get_locale_language()
	if code in LANGS:
		return code
	return "en"


func set_language(next: String) -> void:
	if next not in LANGS:
		next = "en"
	if lang == next:
		return
	lang = next
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("i18n", "lang", lang)
	cfg.save("user://settings.cfg")
	language_changed.emit(lang)


func is_rtl() -> bool:
	return lang in RTL_LANGS


## Text direction for Control nodes. The farm scene ignores this by design.
func text_direction() -> int:
	return Control.TEXT_DIRECTION_RTL if is_rtl() else Control.TEXT_DIRECTION_LTR


## Look up a string, falling back to English and then to the key itself, so a
## missing translation degrades to something readable rather than blank.
func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(lang, {})
	if table.has(key):
		return String(table[key])
	var fallback: Dictionary = STRINGS["en"]
	return String(fallback.get(key, key))


func tf(key: String, args: Array) -> String:
	return t(key) % args


## Server error codes are surfaced as human sentences, never raw codes.
func error_text(code: String) -> String:
	var mapped := t(code)
	if mapped != code:
		return mapped
	return t("connection_error")


## Digits stay Western across all three languages so numbers on the HUD, the
## order cards and the printer sheets are directly comparable.
func number(value: float, decimals: int = 0) -> String:
	if decimals > 0:
		return String.num(value, decimals)
	var n := int(round(value))
	var text := str(absi(n))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
