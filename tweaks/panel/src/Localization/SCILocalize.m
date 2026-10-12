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
        @"versions_match": @"%@ · tested",
        @"versions_differ": @"%@ · tested on %@",
        @"versions_tested_only": @"tested on %@",
        @"versions_unknown": @"not known",
        @"versions_not_installed": @"Not installed on this device",
        @"about_version_panel": @"panel %@",
        @"respring": @"Respring",
        @"respring_confirm": @"The home screen will restart. Nothing is lost — apps you have open will close.",
        @"respring_note": @"Restarts the home screen, which is what makes a newly installed or updated tweak take effect everywhere.",
        @"respring_failed": @"This device would not take the request. Hold the power and volume buttons to restart instead.",
        @"cancel": @"Cancel",
        @"ok_button": @"OK",

        @"about_signature": @"Albrhi — made by Ibrahim Ismail AL-Rahn.\nOpen source under the GNU GPL v3. The Instagram tweak is a derivative of SCInsta by SoCuul, whose authorship is credited and preserved.",
        @"apps_footer": @"Albrhi patches nothing until you switch it on here. Your choice is remembered across updates, and turning an app off keeps its settings. Under each name is the app version on this phone and the one that tweak was last verified against — a newer app usually still works, and this is here so you can see the difference when something does not.",
        @"apps_none": @"No Albrhi tweak is installed",
        @"switch_restart": @"Close and reopen the app for this to take effect.",
        @"ok": @"OK",
        @"section_about": @"About",
        @"about_version": @"Version",
        @"about_author": @"Made by",
        @"about_author_name": @"Ibrahim Ismail AL-Rahn",
        @"about_note": @"A greyed switch means that app is not installed on this device.",
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

        @"master_title": @"Albrhi",
        @"master_footer": @"One switch above all of them. Turn it off and every Albrhi tweak stands down on the next app launch, without changing a single setting below — for the day an app update breaks something and you would rather not hunt through rows.",
        @"apps_footer_master_off": @"Albrhi is switched off above, so none of these are being applied right now. Their settings are kept exactly as they are.",
        @"section_tools": @"Albrhi",
        @"tools_footer": @"What each tweak does, whether a newer version has been published, and a copy of your settings you can keep.",
        @"guide_title": @"Guide",
        @"guide_intro": @"Every Albrhi tweak on this phone, what it does, and the app version it was last verified against. A newer app usually still works — this is here so the difference is visible when something does not.",
        @"guide_tested": @"Verified against",
        @"guide_installed": @"On this phone",
        @"guide_desc_unknown": @"An Albrhi tweak this page has not been told about yet.",
        @"guide_desc_instagram": @"Download posts and reels, a Download Centre queue, control over seen receipts in stories and messages, a follow-back badge, and feed cleanup. Built on SCInsta by SoCuul, GPLv3.",
        @"guide_desc_youtube": @"Downloads with their own tab and player, ad blocking at three layers, SponsorBlock with per-category switches, and background playback.",
        @"guide_desc_twitter": @"Media downloads from every surface at once, and control over the feature switches X uses to decide what the app may do. Settings open with a two-finger hold on the app's own window.",
        @"guide_desc_tiktok": @"An in-feed download button for videos and photo posts, the publish date on each clip, ad filtering, three privacy switches for what is reported back, and a jailbreak-detection bypass. Settings open with a two-finger hold.",
        @"guide_desc_spotify": @"Ad blocking. Carried over from EeveeSpotify under GPLv3, deliberately without its Premium unlock.",
        @"guide_desc_ytmusic": @"Ad blocking and background playback. Carried over from YTMusicUltimate under GPLv3.",
        @"guide_desc_nextup": @"What plays next, on the lock screen and in Control Centre, read from each media app's own queue. A GPLv3 port of NextUp 3 by Yves.",
        @"guide_desc_watch": @"Apple Watch pairing, and holding back watchOS updates you have not asked for.",
        @"update_check": @"Check for updates",
        @"update_asking": @"Asking the source…",
        @"update_unreachable": @"The source could not be reached. Nothing is wrong with what is installed — the question simply went unanswered.",
        @"update_available": @"Albrhi %@ has been published. You have %@.",
        @"update_latest_only": @"The newest published version is %@. This device has no package manager to compare against.",
        @"update_current": @"You are on the newest published version, %@.",
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
        @"versions_match": @"%@ · مُجرَّب",
        @"versions_differ": @"%@ · جُرِّب على %@",
        @"versions_tested_only": @"جُرِّب على %@",
        @"versions_unknown": @"غير معروف",
        @"versions_not_installed": @"غير مثبَّت على هذا الجهاز",
        @"about_version_panel": @"اللوحة %@",
        @"respring": @"إعادة تشغيل الواجهة",
        @"respring_confirm": @"ستُعاد شاشة البداية. لا يضيع شيء — لكن التطبيقات المفتوحة ستُغلق.",
        @"respring_note": @"يعيد تشغيل شاشة البداية، وهو ما يجعل أداة ثُبِّتت أو حُدِّثت للتو تسري في كل مكان.",
        @"respring_failed": @"لم يقبل الجهاز الطلب. أعد التشغيل بزرّي الطاقة ومستوى الصوت بدلاً من ذلك.",
        @"cancel": @"إلغاء",
        @"ok_button": @"حسناً",

        @"about_signature": @"البرهي — تطوير إبراهيم إسماعيل الرهن.\nمفتوح المصدر تحت رخصة GNU GPL v3. أداة إنستغرام مشتقّة من SCInsta لـ SoCuul، ونسبتها إليه محفوظة ومذكورة.",
        @"apps_footer": @"لا يعدّل البرهي شيئًا حتى تُشغّله من هنا. اختيارك محفوظ عبر التحديثات، وإيقاف تطبيق يحتفظ بإعداداته. تحت كل اسم إصدار التطبيق على هذا الجهاز والإصدار الذي جُرِّبت عليه الأداة آخر مرة — الأحدث يعمل غالبًا، وهذا ليظهر لك الفرق حين لا يعمل.",
        @"apps_none": @"لا توجد أداة برهي مثبَّتة",
        @"switch_restart": @"أغلق التطبيق وافتحه ليسري المفعول.",
        @"ok": @"حسناً",
        @"section_about": @"عن اللوحة",
        @"about_version": @"الإصدار",
        @"about_author": @"تطوير",
        @"about_author_name": @"إبراهيم إسماعيل الرهن",
        @"about_note": @"المفتاح الرمادي يعني أن ذلك التطبيق غير مثبَّت على هذا الجهاز.",
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

        @"master_title": @"البرهي",
        @"master_footer": @"مفتاح واحد فوقها جميعاً. أطفئه فتتوقّف كل أدوات البرهي عند فتح التطبيق التالي، دون أن يتغيّر أي إعداد بالأسفل — ليوم يكسر فيه تحديثُ تطبيقٍ شيئاً ولا تريد البحث بين الصفوف.",
        @"apps_footer_master_off": @"البرهي مطفأ بالأعلى، فلا شيء من هذه مُطبَّق الآن. إعداداتها محفوظة كما هي تماماً.",
        @"section_tools": @"البرهي",
        @"tools_footer": @"ما تفعله كل أداة، وهل نُشر إصدار أحدث، ونسخة من إعداداتك تحتفظ بها.",
        @"guide_title": @"الدليل",
        @"guide_intro": @"كل أدوات البرهي على هذا الجهاز، ما تفعله كل واحدة، وإصدار التطبيق الذي جُرِّبت عليه آخر مرّة. الإصدار الأحدث يعمل عادةً — وهذا هنا ليظهر الفرق حين لا يعمل.",
        @"guide_tested": @"مُجرَّبة على",
        @"guide_installed": @"على هذا الجهاز",
        @"guide_desc_unknown": @"أداة من البرهي لم تُعرَّف بها هذه الصفحة بعد.",
        @"guide_desc_instagram": @"تنزيل المنشورات والريلز، وقائمة تنزيلات خاصة، والتحكم في إشعار المشاهدة للقصص والرسائل، وشارة المتابعة المتبادلة، وتنظيف الواجهة. مبنية على SCInsta لـ SoCuul بترخيص GPLv3.",
        @"guide_desc_youtube": @"تنزيلات بتبويب ومشغّل خاصّين، وحجب الإعلانات في ثلاث طبقات، وSponsorBlock بمفاتيح لكل تصنيف، والتشغيل في الخلفية.",
        @"guide_desc_twitter": @"تنزيل الوسائط من كل الأسطح دفعةً واحدة، والتحكم في مفاتيح المميزات التي يقرّر بها إكس ما يفعله التطبيق. تُفتح الإعدادات بضغطة إصبعين على نافذة التطبيق نفسه.",
        @"guide_desc_tiktok": @"زر تحميل داخل الفيديو للمقاطع ومنشورات الصور، وتاريخ النشر على كل مقطع، وتصفية الإعلانات، وثلاثة مفاتيح خصوصية لما يُبلَّغ به الخادم، وتجاوز كشف الجيلبريك. تُفتح الإعدادات بضغطة إصبعين.",
        @"guide_desc_spotify": @"حجب الإعلانات. منقولة من EeveeSpotify بترخيص GPLv3، وعن قصد بلا فتح البريميوم.",
        @"guide_desc_ytmusic": @"حجب الإعلانات والتشغيل في الخلفية. منقولة من YTMusicUltimate بترخيص GPLv3.",
        @"guide_desc_nextup": @"ما سيُشغَّل تالياً، في شاشة القفل ومركز التحكم، مقروءاً من قائمة كل تطبيق وسائط. نقل بترخيص GPLv3 لـ NextUp 3 لـ Yves.",
        @"guide_desc_watch": @"اقتران ساعة آبل، وحجب تحديثات watchOS التي لم تطلبها.",
        @"update_check": @"التحقّق من التحديثات",
        @"update_asking": @"جارٍ سؤال المصدر…",
        @"update_unreachable": @"تعذّر الوصول إلى المصدر. لا خلل فيما هو مثبَّت — السؤال وحده بقي بلا جواب.",
        @"update_available": @"نُشر البرهي %@، ولديك %@.",
        @"update_latest_only": @"أحدث إصدار منشور هو %@. لا يوجد على هذا الجهاز مدير حزم للمقارنة معه.",
        @"update_current": @"أنت على أحدث إصدار منشور، %@.",
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
