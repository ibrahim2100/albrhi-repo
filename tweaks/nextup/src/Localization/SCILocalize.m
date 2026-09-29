//
//  SCILocalize.m
//  Albrhi NextUp — the settings page's own strings.
//
//  They lived in Albrhi Panel's table while this port's settings were a page inside it.
//  NextUp ships its own Settings row now, so it carries its own table: a bundle that
//  reads another package's strings is a bundle that goes mute the day that package is
//  not installed.
//
//  Both tables must hold the same keys — tools/check.py fails the build if they drift.
//

#import "SCILocalize.h"

static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"nextup_advanced_section": @"Advanced",
        @"nextup_app_music": @"Music",
        @"nextup_app_podcasts": @"Podcasts",
        @"nextup_app_soundcloud": @"SoundCloud",
        @"nextup_app_spotify": @"Spotify",
        @"nextup_app_youtube": @"YouTube",
        @"nextup_app_youtube_music": @"YouTube Music",
        @"nextup_apps_footer": @"Each app is read through its own playback queue, so the row shows what that app itself would play next. An app you turn off here is simply never read. Reopen the app for its switch to take effect.\n\nYouTube is the one that behaves differently: a playlist or mix has a real queue, but a standalone video has none, so the row shows YouTube's own autoplay suggestion instead — that one can be played, not skipped or re-ordered, and its cover is 16:9 rather than square.\n\nEach version above is the app build this was written against. A newer app usually still works; when a row goes blank after an update, that number is the first thing to check.",
        @"nextup_apps_section": @"Apps",
        @"nextup_control_center": @"Control Center",
        @"nextup_credit": @"Albrhi NextUp is a port of NextUp 3 by Yves (github.com/Yves000/NextUp3), used under the GNU GPL v3. The design and nearly all of the implementation are his work; this port replaced the settings pane and rebranded the package.",
        @"nextup_dynamic_island": @"Dynamic Island",
        @"nextup_lock_screen": @"Lock Screen",
        @"nextup_log": @"Diagnostic log",
        @"nextup_log_footer": @"Off. Turn it on only while something is wrong: it writes what each process is doing — including the titles of what is playing — to /var/mobile/nu/. Reopen the app or respring for it to take effect, and turn it off again afterwards.",
        @"nextup_master": @"Enabled",
        @"nextup_master_footer": @"Shows what plays next under the now-playing controls, with a cover you can tap to play it now and a button to skip it. Turn this off and nothing is drawn anywhere.",
        @"nextup_page_subtitle": @"What plays next, under the now-playing controls.",
        @"nextup_state_off": @"Off",
        @"nextup_state_on": @"On",
        @"nextup_support_music": @"Full support",
        @"nextup_support_podcasts": @"Full support",
        @"nextup_support_soundcloud": @"Full support · built against 8.75.0",
        @"nextup_support_spotify": @"Full support · built against 9.1.62",
        @"nextup_support_youtube": @"Full support · built against 21.32.4",
        @"nextup_support_youtube_music": @"Full support · built against 9.28.4",
        @"nextup_title": @"Albrhi NextUp",
        @"nextup_where_footer": @"Each surface can be turned off on its own. Changes apply straight away — no respring.",
        @"nextup_where_section": @"Where it shows",
    };

    _arTable = @{
        @"nextup_advanced_section": @"متقدّم",
        @"nextup_app_music": @"الموسيقى",
        @"nextup_app_podcasts": @"البودكاست",
        @"nextup_app_soundcloud": @"ساوند كلاود",
        @"nextup_app_spotify": @"سبوتيفاي",
        @"nextup_app_youtube": @"يوتيوب",
        @"nextup_app_youtube_music": @"يوتيوب ميوزك",
        @"nextup_apps_footer": @"كل تطبيق يُقرأ من قائمة تشغيله الخاصة، فالصف يعرض ما سيشغّله التطبيق نفسه بعد قليل. والتطبيق الذي تطفئه هنا لا يُقرأ أصلاً. أعد فتح التطبيق ليأخذ مفتاحه مفعوله.\n\nويوتيوب هو المختلف: قائمة التشغيل أو الميكس لها طابور حقيقي، أما الفيديو المفرد فلا طابور له — فيُعرض اقتراح التشغيل التلقائي من يوتيوب بدلاً منه، وهذا يمكن تشغيله فقط لا تخطّيه ولا إعادة ترتيبه، وغلافه بنسبة 16:9 لا مربّع.\n\nوكل إصدار أعلاه هو بناء التطبيق الذي كُتبت عليه الأداة. الأحدث يعمل غالباً؛ وحين يفرغ الصف بعد تحديث، فهذا الرقم أول ما يُراجَع.",
        @"nextup_apps_section": @"التطبيقات",
        @"nextup_control_center": @"مركز التحكم",
        @"nextup_credit": @"البرهي نكست أب نقلٌ لأداة NextUp 3 من Yves ‏(github.com/Yves000/NextUp3)، مستخدمة بموجب رخصة GNU GPL v3. التصميم وأغلب التنفيذ عمله هو؛ وهذا النقل استبدل صفحة الإعدادات وأعاد تسمية الحزمة.",
        @"nextup_dynamic_island": @"الجزيرة الديناميكية",
        @"nextup_lock_screen": @"شاشة القفل",
        @"nextup_log": @"سجل التشخيص",
        @"nextup_log_footer": @"مطفأ. شغّله فقط حين يوجد خلل: يكتب ما تفعله كل عملية — ومنه عناوين ما يُشغَّل — في /var/mobile/nu/. أعد فتح التطبيق أو أعد التشغيل ليأخذ مفعوله، ثم أطفئه بعدها.",
        @"nextup_master": @"مُفعَّل",
        @"nextup_master_footer": @"يعرض ما سيُشغَّل تالياً أسفل أزرار التشغيل، مع غلاف تضغطه ليُشغَّل الآن وزر لتخطّيه. أوقفه ولن يُرسم شيء في أي مكان.",
        @"nextup_page_subtitle": @"ما سيُشغَّل بعد قليل، تحت أزرار التشغيل.",
        @"nextup_state_off": @"مُطفأ",
        @"nextup_state_on": @"مُفعَّل",
        @"nextup_support_music": @"دعم كامل",
        @"nextup_support_podcasts": @"دعم كامل",
        @"nextup_support_soundcloud": @"دعم كامل · مبنية على 8.75.0",
        @"nextup_support_spotify": @"دعم كامل · مبنية على 9.1.62",
        @"nextup_support_youtube": @"دعم كامل · مبنية على 21.32.4",
        @"nextup_support_youtube_music": @"دعم كامل · مبنية على 9.28.4",
        @"nextup_title": @"البرهي نكست أب",
        @"nextup_where_footer": @"كل واجهة يمكن إيقافها وحدها. التغييرات تسري فوراً — بلا إعادة تشغيل للواجهة.",
        @"nextup_where_section": @"أين يظهر",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SCIBuildTables(); });

    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    NSDictionary *table = [language hasPrefix:@"ar"] ? _arTable : _enTable;

    return table[key] ?: (_enTable[key] ?: key);
}
