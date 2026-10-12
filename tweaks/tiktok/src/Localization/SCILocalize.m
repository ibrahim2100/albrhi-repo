#import "SCILocalize.h"

///
/// Every user-facing string, in both languages.
///
/// The two tables must hold the same keys; tools/check.py fails the build if they drift, if
/// a key is used but never defined, or if a stray quote inside a value leaves Objective-C
/// reading prose as code.
///

static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"title": @"Albrhi for TikTok",
        @"done": @"Done",

        @"section_privacy": @"Privacy",

        // The settings screen's own sections, named by what a person came here to change
        // rather than by which part of the code owns them.
        @"recalled_badge": @"🗑 taken back · ",
        @"section_extras": @"Extras",
        @"row_accounts": @"More logged-in accounts",
        @"row_accounts_note": @"TikTok caps how many accounts may be signed in at once, and the cap is enforced in the app. Raised, not removed.",
        @"row_keep_recalled": @"Keep messages that were taken back",
        @"row_keep_recalled_note": @"A direct message the sender recalled stays visible. TikTok had already delivered it and then received an instruction to hide it; hiding is the app's own doing, and this refuses that instruction. Nothing is fetched back from a server.",
        @"status_video_date": @"Publish date",
        @"status_extras": @"Extras",
        @"row_video_date": @"Show when it was posted",
        @"row_video_date_note": @"The publish date under Albrhi's own button, read from the video's own createTime and drawn in a frame this tweak owns — never handed to one of TikTok's rails, which rebuild their contents and sweep guests out.",
        @"row_visitors": @"Remember profile visitors",
        @"row_visitors_note": @"Keeps its own record of who opened your profile as TikTok delivers them, so somebody who blocks you afterwards does not erase what already arrived. TikTok's own list is never modified — Albrhi shows its record here.",
        @"section_confirm": @"Confirmations",
        @"row_confirm_like": @"Ask before liking",
        @"row_confirm_like_note": @"Both the heart and the double tap on the video. It asks whichever way the like was about to happen.",
        @"row_confirm_follow": @"Ask before following",
        @"row_confirm_follow_note": @"The follow button on the feed and on a profile.",
        @"confirm_like_title": @"Like this video?",
        @"confirm_follow_title": @"Follow this account?",
        @"confirm_yes": @"Yes",
        @"status_confirm": @"Confirmations",

        @"section_download": @"Download",
        @"section_watching": @"Watching",
        @"section_protection": @"Protection",
        @"section_advanced": @"Advanced",

        @"row_report": @"Status report",
        @"row_report_note": @"Every number behind every feature, and one tap to copy the lot.",
        @"report_title": @"Status report",
        @"copy_report_all": @"Copy everything",
        @"status_heavy_summary": @"%lu entries — sent with Copy everything",
        @"copy_report": @"Copy",

        @"section_overview": @"Overview",
        @"section_quality": @"Quality",
        @"section_resolution": @"Link resolution",

        @"row_ads": @"Hide ads",
        @"row_ads_note": @"A feed item marked as an ad by TikTok's own server is never built into a cell.",
        @"row_download_button": @"Download button in the feed",
        @"row_download_button_note": @"A button beside like, comment and share on the video on screen.",
        @"status_playback": @"Player picker signature",
        @"status_watermark": @"Watermark",
        @"status_measured": @"Measured link sizes",
        @"row_external_hd": @"HD from an outside service",
        @"row_external_hd_note": @"Fetches the original upload through an outside service — measured at 60fps and three times the size where TikTok's own stream was 30fps. It tells a service outside TikTok which video you are watching. Off unless you turn it on.",
        @"status_gears": @"Quality gears offered",
        @"status_progress_bar": @"Seek bar",
        @"row_photo_download": @"Save photo posts",
        @"row_photo_download_note": @"A photo post saves every image in it, each one its own entry in Photos.",
        @"row_progress_bar": @"Always show the seek bar",
        @"row_progress_bar_note": @"TikTok hides the bar under the video unless you are dragging it. This keeps it there.",
        @"row_bypass": @"Hide the jailbreak",
        @"row_bypass_note": @"Answers TikTok's own device checks the way an unmodified phone would.",

        @"row_privacy_story": @"Story views",
        @"row_privacy_story_note": @"Stops the seen mark a story's author would otherwise get.",
        @"row_privacy_messages": @"Message read receipts",
        @"row_privacy_messages_note": @"Stops the read receipt sent to the other side. Your own unread badge still clears normally.",
        @"row_privacy_profile": @"Profile views",
        @"row_privacy_profile_note": @"Stops the report sent when you open someone's profile.",


        @"status_gate": @"Panel switch",
        @"gate_on": @"On",
        @"gate_off": @"Off — turn TikTok on in Settings › Albrhi",

        @"status_button": @"In-feed button",
        @"status_media_resolve": @"Video link resolution",
        @"status_media_candidates": @"Possible video accessors",
        @"status_video_accessors": @"Video model accessors",
        @"status_cell_accessors": @"Feed cell model accessors",
        @"status_download": @"Last save attempt",

        @"diag_ads": @"Ad filter",
        @"diag_ads_none": @"Nothing seen yet. Scroll the feed, then come back.",
        @"diag_ads_counts": @"%lu dropped of %lu feed items seen",

        @"diag_bypass": @"Bypass",
        @"diag_bypass_none": @"Nothing asked yet.",

        @"diag_privacy": @"Privacy",
        @"diag_privacy_none": @"Nothing asked yet.",

        @"welcome_title": @"Albrhi is on TikTok",
        @"welcome_subtitle": @"%@ — here is what changed, and where to find it.",
        @"welcome_download": @"A download button in the feed",
        @"welcome_download_note": @"Above the profile picture, on every video. It saves what you are watching, at the best quality TikTok offers it.",
        @"welcome_photos": @"Photo posts, properly",
        @"welcome_photos_note": @"It asks whether you want the picture you are on or all of them — and one picture can be saved as a short video with the post's sound over it.",
        @"welcome_clean": @"Quieter, and less reported",
        @"welcome_clean_note": @"Ads are dropped before they are built, and story views, read receipts and profile views are not sent back.",
        @"welcome_settings": @"Hold two fingers to open the settings",
        @"welcome_settings_note": @"Anywhere in TikTok. Every switch lives there, with the full status report one row away.",
        @"welcome_start": @"Let's go",
        @"row_welcome": @"Show the welcome screen",
        @"row_welcome_note": @"The first-run screen again, with what each feature does and where it is.",

        @"photos_ask_message": @"You are on picture %lu of %lu.",
        @"audio_ask_title": @"Add the sound?",
        @"audio_ask_message": @"The picture is saved as a video with the post's sound over it.",
        @"audio_seconds": @"%.0f seconds",
        @"audio_picture_only": @"Picture only",
        @"audio_working": @"Making the clip…",
        @"audio_done": @"Clip saved to Photos",
        @"row_photo_audio": @"Offer the sound with a picture",
        @"row_photo_audio_note": @"Saving one picture asks whether to lay the post's sound over it and save a short video instead.",

        @"status_photos": @"Photo post chain",
        @"photos_ask_title": @"This is a photo post",
        @"photos_save_this": @"Save this picture",
        @"photos_save_all": @"Save all %lu",
        @"photos_cancel": @"Cancel",
        @"photos_saved_count": @"Saved %lu of %lu",
        @"save_working": @"Saving…",
        @"save_failed": @"Couldn't save it",
        @"save_done": @"Saved to Photos",
        @"save_no_permission": @"Photos access is off",

        @"report_copied": @"Report copied",
        @"row_hide_online": @"Never appear online",
        @"row_hide_online_note": @"TikTok stops being told you are active. Four separate reports are refused, and nothing false is sent in their place.",
        @"row_no_loop": @"Do not repeat a video",
        @"row_no_loop_note": @"A clip that reaches its end stays there instead of starting again. It does not move to the next video.",
        @"section_count": @"%lu options",
        @"hero_tally": @"%ld of %ld on",
    };

    _arTable = @{
        @"title": @"البرهي لتيك توك",
        @"done": @"تم",

        @"section_privacy": @"الخصوصية",

        @"recalled_badge": @"🗑 مسحوبة · ",
        @"section_extras": @"إضافات",
        @"row_accounts": @"حسابات أكثر",
        @"row_accounts_note": @"يحدّ تيك توك عدد الحسابات المسجَّلة معاً، والحدّ يفرضه التطبيق نفسه. رُفع، ولم يُلغَ.",
        @"row_keep_recalled": @"إبقاء الرسائل المسحوبة",
        @"row_keep_recalled_note": @"الرسالة التي يسحبها مرسلها تبقى ظاهرة. فتيك توك سلّمها ثم وصلته تعليمات إخفائها، والإخفاء يفعله التطبيق — وهذا رفضٌ لتلك التعليمات. ولا يُجلَب شيء من أي خادم.",
        @"status_video_date": @"تاريخ النشر",
        @"status_extras": @"الإضافات",
        @"row_video_date": @"إظهار تاريخ النشر",
        @"row_video_date_note": @"تاريخ نشر المقطع تحت زرّ البرهي، مقروءاً من createTime الخاص بالفيديو ومرسوماً في إطارٍ تملكه الأداة — لا يُسلَّم لأحد أشرطة تيك توك، فهي تُعيد بناء محتواها وتكنس الضيوف.",
        @"row_visitors": @"تذكّر زوّار الملف",
        @"row_visitors_note": @"يحتفظ بسجلّه الخاص لمن فتح ملفك، لحظة يسلّمهم تيك توك — فمن يحظرك بعدها لا يمحو ما وصل فعلاً. ولا تُعدَّل قائمة تيك توك نفسها؛ البرهي يعرض سجلّه هنا.",
        @"section_confirm": @"التأكيدات",
        @"row_confirm_like": @"اسألني قبل الإعجاب",
        @"row_confirm_like_note": @"القلب والنقر المزدوج على الفيديو معاً. يسأل بأيّ الطريقتين كان الإعجاب سيحدث.",
        @"row_confirm_follow": @"اسألني قبل المتابعة",
        @"row_confirm_follow_note": @"زر المتابعة في الفيديو وفي صفحة الحساب.",
        @"confirm_like_title": @"إعجاب بهذا الفيديو؟",
        @"confirm_follow_title": @"متابعة هذا الحساب؟",
        @"confirm_yes": @"نعم",
        @"status_confirm": @"التأكيدات",

        @"section_download": @"التحميل",
        @"section_watching": @"المشاهدة",
        @"section_protection": @"الحماية",
        @"section_advanced": @"متقدّم",

        @"row_report": @"تقرير الحالة",
        @"row_report_note": @"كل رقم خلف كل ميزة، ونسخها كلها بلمسة.",
        @"report_title": @"تقرير الحالة",
        @"copy_report_all": @"نسخ الكل",
        @"status_heavy_summary": @"%lu عنصراً — تُرسَل مع «نسخ الكل»",
        @"copy_report": @"نسخ",

        @"section_overview": @"نظرة عامة",
        @"section_quality": @"الجودة",
        @"section_resolution": @"استخراج الرابط",

        @"row_ads": @"إخفاء الإعلانات",
        @"row_ads_note": @"أي عنصر يعلّمه سيرفر تيك توك نفسه كإعلان لا يُبنى ككائن أصلاً.",
        @"row_download_button": @"زر تحميل في الواجهة",
        @"row_download_button_note": @"زر بجانب اللايك والتعليق والمشاركة على الفيديو المعروض.",
        @"status_playback": @"توقيع منتقي المشغّل",
        @"status_watermark": @"العلامة المائية",
        @"status_measured": @"أحجام الروابط المقاسة",
        @"row_external_hd": @"HD من خدمة خارجية",
        @"row_external_hd_note": @"يجلب النسخة الأصلية المرفوعة عبر خدمة خارجية — قيست بـ60 إطاراً وثلاثة أضعاف الحجم حيث كان بثّ تيك توك 30 إطاراً. يُعلم خدمة خارج تيك توك بالفيديو الذي تشاهده. مطفأ حتى تُشغّله بنفسك.",
        @"status_gears": @"مستويات الجودة المتاحة",
        @"status_progress_bar": @"شريط التقدم",
        @"row_photo_download": @"حفظ منشورات الصور",
        @"row_photo_download_note": @"منشور الصور يُحفَظ بكل صوره، كل صورة كعنصر مستقل في الصور.",
        @"row_progress_bar": @"إظهار شريط التقدم دائماً",
        @"row_progress_bar_note": @"تيك توك يخفي الشريط أسفل الفيديو إلا أثناء سحبه. هذا يبقيه ظاهراً.",
        @"row_bypass": @"إخفاء الجيلبريك",
        @"row_bypass_note": @"يجاوب على فحوصات تيك توك للجهاز كأنه جهاز غير معدَّل.",

        @"row_privacy_story": @"مشاهدة القصص",
        @"row_privacy_story_note": @"يوقف علامة المشاهدة اللي يشوفها صاحب القصة.",
        @"row_privacy_messages": @"تأكيد قراءة الرسائل",
        @"row_privacy_messages_note": @"يوقف تأكيد القراءة اللي يوصل للطرف الثاني. الشارة عندك تستمر تُمسح بشكل طبيعي.",
        @"row_privacy_profile": @"زيارة البروفايلات",
        @"row_privacy_profile_note": @"يوقف التقرير اللي يُرسل عند فتحك لبروفايل أحد.",


        @"status_gate": @"مفتاح البانل",
        @"gate_on": @"مفعّل",
        @"gate_off": @"مغلق — فعّل تيك توك من الإعدادات › البرهي",

        @"status_button": @"زر الواجهة",
        @"status_media_resolve": @"تحليل رابط الفيديو",
        @"status_media_candidates": @"دوال محتملة للفيديو",
        @"status_video_accessors": @"وصولات نموذج الفيديو",
        @"status_cell_accessors": @"دوال موديل خلية الفيد",
        @"status_download": @"آخر محاولة حفظ",

        @"diag_ads": @"فلتر الإعلانات",
        @"diag_ads_none": @"لا شيء بعد. مرّر بالفيد ثم ارجع.",
        @"diag_ads_counts": @"%lu مُسقَط من %lu عنصر فيد",

        @"diag_bypass": @"الإخفاء",
        @"diag_bypass_none": @"لا شيء سُئل بعد.",

        @"diag_privacy": @"الخصوصية",
        @"diag_privacy_none": @"لا شيء سُئل بعد.",

        @"welcome_title": @"البرهي داخل تيك توك",
        @"welcome_subtitle": @"%@ — هذا ما أُضيف، وأين تجده.",
        @"welcome_download": @"زر تحميل في الواجهة",
        @"welcome_download_note": @"فوق صورة الحساب، على كل فيديو. يحفظ ما تشاهده، بأفضل جودة يقدّمها تيك توك له.",
        @"welcome_photos": @"منشورات الصور، كما يجب",
        @"welcome_photos_note": @"يسألك: الصورة التي أنت عليها أم كلها — ويمكن حفظ صورة واحدة مقطعاً قصيراً وصوت المنشور فوقها.",
        @"welcome_clean": @"أهدأ، وأقل إبلاغاً",
        @"welcome_clean_note": @"الإعلانات تُرفض قبل أن تُبنى، ومشاهدة القصص وإيصالات القراءة وزيارات الحسابات لا تُرسَل.",
        @"welcome_settings": @"اضغط بإصبعين لفتح الإعدادات",
        @"welcome_settings_note": @"في أي مكان داخل تيك توك. كل المفاتيح هناك، وتقرير الحالة الكامل على بُعد صف واحد.",
        @"welcome_start": @"يلا نبدأ",
        @"row_welcome": @"اعرض شاشة الترحيب",
        @"row_welcome_note": @"شاشة أول تشغيل مرة أخرى، بما تفعله كل ميزة وأين هي.",

        @"photos_ask_message": @"أنت على الصورة %lu من %lu.",
        @"audio_ask_title": @"نضيف الصوت؟",
        @"audio_ask_message": @"تُحفَظ الصورة فيديو وصوت المنشور فوقها.",
        @"audio_seconds": @"%.0f ثانية",
        @"audio_picture_only": @"الصورة فقط",
        @"audio_working": @"يجهّز المقطع…",
        @"audio_done": @"حُفِظ المقطع في الصور",
        @"row_photo_audio": @"اعرض الصوت مع الصورة",
        @"row_photo_audio_note": @"حفظ صورة واحدة يسأل إن أردت وضع صوت المنشور فوقها وحفظها فيديو قصير.",

        @"status_photos": @"سلسلة منشور الصور",
        @"photos_ask_title": @"هذا منشور صور",
        @"photos_save_this": @"حفظ هذه الصورة",
        @"photos_save_all": @"حفظ الكل (%lu)",
        @"photos_cancel": @"إلغاء",
        @"photos_saved_count": @"حُفظت %lu من %lu",
        @"save_working": @"جارِ الحفظ…",
        @"save_failed": @"تعذّر الحفظ",
        @"save_done": @"تم الحفظ في الصور",
        @"save_no_permission": @"صلاحية الصور مغلقة",

        @"report_copied": @"تم نسخ التقرير",
        @"row_hide_online": @"لا تظهر متصلاً",
        @"row_hide_online_note": @"يتوقّف إبلاغ تيك توك بأنك نشط. تُرفض أربعة بلاغات منفصلة، ولا يُرسل مكانها شيء غير صحيح.",
        @"row_no_loop": @"عدم تكرار الفيديو",
        @"row_no_loop_note": @"المقطع الذي ينتهي يبقى عند نهايته بدل أن يبدأ من جديد. ولا ينتقل إلى الفيديو التالي.",
        @"section_count": @"%lu خيارات",
        @"hero_tally": @"%ld من %ld مُفعَّل",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SCIBuildTables();
    });

    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    BOOL arabic = [language hasPrefix:@"ar"];

    NSDictionary *table = arabic ? _arTable : _enTable;
    NSString *value = table[key];

    return value ?: (_enTable[key] ?: key);
}
