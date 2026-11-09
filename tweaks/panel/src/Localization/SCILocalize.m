#import "SCILocalize.h"

///
/// Every user-facing string, in both languages.
///
/// The two tables must hold the same keys; tools/check.py fails the build if they
/// drift, if a key is used but never defined, or if a stray quote inside a value
/// leaves Objective-C reading prose as code.
///

static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"panel_title": @"Albrhi",
        @"panel_on_count": @"%ld of %ld on",
        @"panel_tagline": @"One tweak for every app it supports, switched from here.",
        @"section_apps": @"Apps",
        @"versions_unknown": @"not known",
        @"versions_not_installed": @"Not installed on this device",
        @"about_version_panel": @"panel %@",
        @"respring": @"Respring",
        @"respring_confirm": @"The home screen will restart. Nothing is lost — apps you have open will close.",
        @"respring_note": @"Restarts the home screen, which is what makes a newly installed or updated tweak take effect everywhere.",
        @"respring_failed": @"This device would not take the request. Hold the power and volume buttons to restart instead.",
        @"cancel": @"Cancel",

        @"about_signature": @"Albrhi — made by Ibrahim Ismail AL-Rahn.\nOpen source under the GNU GPL v3. The Instagram tweak is a derivative of SCInsta by SoCuul, whose authorship is credited and preserved.",
        @"apps_footer": @"Albrhi patches nothing until you switch an app on here — then reopen that app. A dimmed row means that app is not installed. Versions are in the Guide.",
        @"apps_none": @"No Albrhi tweak is installed",
        @"ok": @"OK",
        @"section_about": @"About",
        @"about_version": @"Version",
        @"about_author": @"Made by",
        @"about_author_name": @"Ibrahim Ismail AL-Rahn",
        @"tweak_page_missing": @"Installed, but its settings page is not — update Albrhi from Sileo.",
        @"section_tweaks": @"Tweaks",
        @"tweaks_footer": @"These run across several processes rather than patching one app, so each has a page of its own. Their switches live inside those pages, not here.",
        @"spotify_master": @"Albrhi for Spotify",
        @"spotify_gate_on": @"ON — active the next time Spotify starts.",
        @"spotify_gate_off": @"OFF — nothing below is active.",
        @"spotify_no_premium": @"ADS ONLY. This does not unlock Premium: it does not touch your account, does not report you as a subscriber, and does not remove the skip limit. It blocks advertising, on a free account exactly as on a paid one.",
        @"spotify_ads_section": @"Advertising",
        @"spotify_ads_footer": @"The ad services are refused when Spotify asks for them, and the home feed's sponsored rows are filtered out before the screen is built. Reopen Spotify for a change to take effect.",
        @"spotify_block_ads": @"Block ads",
        @"spotify_block_upsell": @"Block Premium popups",
        @"spotify_podcast_section": @"Podcasts",
        @"spotify_sponsorblock": @"Skip sponsored segments",
        @"spotify_sponsorblock_footer": @"Sponsored, self-promotion and interruption segments in podcasts, from SponsorBlock's community database. OFF by default because it asks a third-party server about what is playing — a cost worth paying only if you choose it. Submitting and voting on segments is not included.",
        @"spotify_credit": @"The ad blocking is EeveeSpotify by Eevee and the SideloadLabs team, under GPLv3 — the same licence Albrhi ships under, which is what makes carrying it over lawful. Its subscription unlock is deliberately not included.",

        @"hero_off": @"Off",
        @"master_status_one": @"Active in 1 app",
        @"master_status_on": @"Active in %ld apps",
        @"master_status_none": @"Nothing is switched on yet",
        @"master_status_off": @"All Albrhi tweaks are paused",
        @"section_updates": @"Updates",
        @"updates_footer": @"Albrhi asks its source only when you tap, never in the background. The version above is what this phone has installed.",
        @"update_row_title": @"Albrhi %@",
        @"update_idle": @"Tap to check for a newer version",
        @"update_checking": @"Asking the source…",
        @"update_inline_current": @"You have the newest version",
        @"update_inline_available": @"%@ is available — update from Sileo",
        @"update_inline_unreachable": @"Could not reach the source — try again",
        @"update_inline_latest_only": @"Newest published: %@",
        @"master_title": @"Albrhi",
        @"master_footer": @"One switch above all of them. Turn it off and every Albrhi tweak stands down the next time an app opens. Nothing below is changed.",
        @"apps_footer_master_off": @"Albrhi is switched off above, so none of these are being applied right now. Their settings are kept exactly as they are.",
        @"section_tools": @"Guide & backup",
        @"tools_footer": @"What each tweak does, and a copy of your settings you can keep.",
        @"guide_line_match": @"%@ on this phone · verified",
        @"guide_line_differ": @"%@ on this phone · verified on %@",
        @"guide_line_tested_only": @"Verified on %@",
        @"guide_title": @"Guide",
        @"guide_intro": @"Every Albrhi tweak on this phone, what it does, and the app version it was last verified against. A newer app usually still works — this is here so the difference is visible when something does not.",
        @"guide_desc_unknown": @"An Albrhi tweak this page has not been told about yet.",
        @"guide_desc_instagram": @"Download posts and reels, a Download Centre queue, control over seen receipts in stories and messages, a follow-back badge, and feed cleanup. Built on SCInsta by SoCuul, GPLv3.",
        @"guide_desc_youtube": @"Downloads with their own tab and player, ad blocking at three layers, SponsorBlock with per-category switches, and background playback.",
        @"guide_desc_twitter": @"Media downloads from every surface at once, and control over the feature switches X uses to decide what the app may do. Settings open with a two-finger hold on the app's own window.",
        @"guide_desc_tiktok": @"An in-feed download button for videos and photo posts, the publish date on each clip, ad filtering, three privacy switches for what is reported back, and a jailbreak-detection bypass. Settings open with a two-finger hold.",
        @"guide_desc_spotify": @"Ad blocking. Carried over from EeveeSpotify under GPLv3, deliberately without its Premium unlock.",
        @"guide_desc_ytmusic": @"Ad blocking and background playback. Carried over from YTMusicUltimate under GPLv3.",
        @"guide_desc_nextup": @"What plays next, on the lock screen and in Control Centre, read from each media app's own queue. A GPLv3 port of NextUp 3 by Yves.",
        @"guide_desc_watch": @"Apple Watch pairing, and holding back watchOS updates you have not asked for.",
        @"backup_export": @"Save a copy of your settings",
        @"backup_import": @"Restore settings from a file",
        @"backup_failed": @"The settings could not be read.",
        @"backup_not_ours": @"That file is not an Albrhi settings backup. Nothing was changed.",
        @"backup_restored": @"%ld setting(s) restored. Reopen the apps for them to take effect.",
    };

    _arTable = @{
        @"panel_title": @"البرهي",
        @"panel_on_count": @"%ld من %ld مُشغَّل",
        @"panel_tagline": @"أداة واحدة لكل تطبيق تدعمه، تتحكم بها من هنا.",
        @"section_apps": @"التطبيقات",
        @"versions_unknown": @"غير معروف",
        @"versions_not_installed": @"غير مثبَّت على هذا الجهاز",
        @"about_version_panel": @"اللوحة %@",
        @"respring": @"إعادة تشغيل الواجهة",
        @"respring_confirm": @"ستُعاد شاشة البداية. لا يضيع شيء — لكن التطبيقات المفتوحة ستُغلق.",
        @"respring_note": @"يعيد تشغيل شاشة البداية، وهو ما يجعل أداة ثُبِّتت أو حُدِّثت للتو تسري في كل مكان.",
        @"respring_failed": @"لم يقبل الجهاز الطلب. أعد التشغيل بزرّي الطاقة ومستوى الصوت بدلاً من ذلك.",
        @"cancel": @"إلغاء",

        @"about_signature": @"البرهي — تطوير إبراهيم إسماعيل الرهن.\nمفتوح المصدر تحت رخصة GNU GPL v3. أداة إنستغرام مشتقّة من SCInsta لـ SoCuul، ونسبتها إليه محفوظة ومذكورة.",
        @"apps_footer": @"لا يعدّل البرهي شيئاً حتى تشغّل التطبيق من هنا — ثم أعد فتحه. والصف الباهت يعني أن التطبيق غير مثبَّت. أرقام الإصدارات في الدليل.",
        @"apps_none": @"لا توجد أداة برهي مثبَّتة",
        @"ok": @"حسناً",
        @"section_about": @"عن اللوحة",
        @"about_version": @"الإصدار",
        @"about_author": @"تطوير",
        @"about_author_name": @"إبراهيم إسماعيل الرهن",
        @"tweak_page_missing": @"مثبَّتة، لكن صفحة إعداداتها ليست كذلك — حدّث البرهي من Sileo.",
        @"section_tweaks": @"الأدوات",
        @"tweaks_footer": @"هذه تعمل عبر عدة عمليات بدل تعديل تطبيق واحد، فلكل واحدة صفحتها. مفاتيحها داخل تلك الصفحات لا هنا.",
        @"spotify_master": @"البرهي لسبوتيفاي",
        @"spotify_gate_on": @"مُفعَّلة — تعمل عند تشغيل سبوتيفاي التالي.",
        @"spotify_gate_off": @"مطفأة — لا شيء تحتها يعمل.",
        @"spotify_no_premium": @"الإعلانات فقط. هذه الأداة لا تفتح Premium: لا تمسّ حسابك، ولا تُبلّغ عنك كمشترك، ولا تُلغي حدّ التخطّي. تحجب الإعلانات، على الحساب المجاني كما على المدفوع تماماً.",
        @"spotify_ads_section": @"الإعلانات",
        @"spotify_ads_footer": @"تُرفَض خدمات الإعلانات حين يطلبها سبوتيفاي، وتُرشَّح الصفوف المموَّلة من الواجهة الرئيسية قبل بنائها. أعد فتح سبوتيفاي ليأخذ التغيير مفعوله.",
        @"spotify_block_ads": @"حجب الإعلانات",
        @"spotify_block_upsell": @"حجب نوافذ Premium",
        @"spotify_podcast_section": @"البودكاست",
        @"spotify_sponsorblock": @"تخطّي المقاطع الإعلانية",
        @"spotify_sponsorblock_footer": @"المقاطع المموَّلة والترويج الذاتي والمقاطعات في البودكاست، من قاعدة SponsorBlock المجتمعية. مطفأة افتراضياً لأنها تسأل خادماً خارجياً عمّا يُشغَّل — كلفةٌ لا تُدفع إلا باختيارك. أما إرسال المقاطع والتصويت عليها فغير مُدرَجَين.",
        @"spotify_credit": @"حجب الإعلانات من EeveeSpotify لـ Eevee وفريق SideloadLabs، برخصة GPLv3 — نفس رخصة البرهي، وهي ما يجعل نقلها مشروعاً. أما فتح الاشتراك عندهم فغير مُدرَجٍ عمداً.",

        @"hero_off": @"مطفأ",
        @"master_status_one": @"يعمل في تطبيق واحد",
        @"master_status_on": @"يعمل في %ld تطبيقات",
        @"master_status_none": @"لم يُفعَّل شيء بعد",
        @"master_status_off": @"كل أدوات البرهي متوقفة مؤقتاً",
        @"section_updates": @"التحديثات",
        @"updates_footer": @"يسأل البرهي مصدره عند نقرك فقط، ولا يسأل أبداً في الخلفية. الإصدار أعلاه هو المثبَّت على هذا الجوال.",
        @"update_row_title": @"البرهي %@",
        @"update_idle": @"انقر للتحقق من إصدار أحدث",
        @"update_checking": @"جارٍ سؤال المصدر…",
        @"update_inline_current": @"لديك أحدث إصدار",
        @"update_inline_available": @"%@ متاح — حدّث من Sileo",
        @"update_inline_unreachable": @"تعذّر الوصول إلى المصدر — أعد المحاولة",
        @"update_inline_latest_only": @"أحدث إصدار منشور: %@",
        @"master_title": @"البرهي",
        @"master_footer": @"مفتاح واحد فوقها جميعاً. أطفئه فتتوقف كل أدوات البرهي عند فتح أي تطبيق في المرة القادمة. ولا يتغيّر شيء مما تحته.",
        @"apps_footer_master_off": @"البرهي مطفأ بالأعلى، فلا شيء من هذه مُطبَّق الآن. إعداداتها محفوظة كما هي تماماً.",
        @"section_tools": @"الدليل والنسخ الاحتياطي",
        @"tools_footer": @"ما تفعله كل أداة، ونسخة من إعداداتك تحتفظ بها.",
        @"guide_line_match": @"%@ على هذا الجوال · مُجرَّب",
        @"guide_line_differ": @"%@ على هذا الجوال · جُرِّب على %@",
        @"guide_line_tested_only": @"جُرِّب على %@",
        @"guide_title": @"الدليل",
        @"guide_intro": @"كل أدوات البرهي على هذا الجهاز، ما تفعله كل واحدة، وإصدار التطبيق الذي جُرِّبت عليه آخر مرّة. الإصدار الأحدث يعمل عادةً — وهذا هنا ليظهر الفرق حين لا يعمل.",
        @"guide_desc_unknown": @"أداة من البرهي لم تُعرَّف بها هذه الصفحة بعد.",
        @"guide_desc_instagram": @"تنزيل المنشورات والريلز، وقائمة تنزيلات خاصة، والتحكم في إشعار المشاهدة للقصص والرسائل، وشارة المتابعة المتبادلة، وتنظيف الواجهة. مبنية على SCInsta لـ SoCuul بترخيص GPLv3.",
        @"guide_desc_youtube": @"تنزيلات بتبويب ومشغّل خاصّين، وحجب الإعلانات في ثلاث طبقات، وSponsorBlock بمفاتيح لكل تصنيف، والتشغيل في الخلفية.",
        @"guide_desc_twitter": @"تنزيل الوسائط من كل الأسطح دفعةً واحدة، والتحكم في مفاتيح المميزات التي يقرّر بها إكس ما يفعله التطبيق. تُفتح الإعدادات بضغطة إصبعين على نافذة التطبيق نفسه.",
        @"guide_desc_tiktok": @"زر تحميل داخل الفيديو للمقاطع ومنشورات الصور، وتاريخ النشر على كل مقطع، وتصفية الإعلانات، وثلاثة مفاتيح خصوصية لما يُبلَّغ به الخادم، وتجاوز كشف الجيلبريك. تُفتح الإعدادات بضغطة إصبعين.",
        @"guide_desc_spotify": @"حجب الإعلانات. منقولة من EeveeSpotify بترخيص GPLv3، وعن قصد بلا فتح البريميوم.",
        @"guide_desc_ytmusic": @"حجب الإعلانات والتشغيل في الخلفية. منقولة من YTMusicUltimate بترخيص GPLv3.",
        @"guide_desc_nextup": @"ما سيُشغَّل تالياً، في شاشة القفل ومركز التحكم، مقروءاً من قائمة كل تطبيق وسائط. نقل بترخيص GPLv3 لـ NextUp 3 لـ Yves.",
        @"guide_desc_watch": @"اقتران ساعة آبل، وحجب تحديثات watchOS التي لم تطلبها.",
        @"backup_export": @"حفظ نسخة من إعداداتك",
        @"backup_import": @"استعادة الإعدادات من ملف",
        @"backup_failed": @"تعذّرت قراءة الإعدادات.",
        @"backup_not_ours": @"هذا الملف ليس نسخة إعدادات من البرهي. لم يتغيّر شيء.",
        @"backup_restored": @"استُعيد %ld إعداداً. أعد فتح التطبيقات ليسري المفعول.",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SCIBuildTables();
    });

    // The device's own preference. Someone whose phone is Arabic is an Arabic reader, and
    // these strings are the panel's own rather than any app's.
    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    BOOL arabic = [language hasPrefix:@"ar"];

    NSDictionary *table = arabic ? _arTable : _enTable;
    NSString *value = table[key];

    return value ?: (_enTable[key] ?: key);
}
