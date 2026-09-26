//
//  SCILocalize.m
//  Albrhi for YouTube Music
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCILocalize.h"

NSString *SCIVersionString = @"v0.9.3";  // AlbrhiYTM

/// Short, because everything a person reads about this tweak is drawn by Albrhi Panel: it patches
/// one app, so it takes one row on the app list rather than a page of its own.
static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"title": @"Albrhi for YouTube Music",
        @"sb_skip": @"Skip",
        @"sb_unskip": @"Unskip",
        @"sb_skipped": @"Segment skipped",
        @"sb_found": @"Segment found",
        @"download_started": @"Saving",
        @"dl_confirm_title": @"Save this track",
        @"dl_confirm_note": @"Name it, and choose a section to keep it in. Leave the section empty for the main library.",
        @"dl_confirm_name": @"Name",
        @"dl_confirm_section": @"Section",
        @"dl_confirm_save": @"Save",
        @"download_started_note": @"The track is being fetched. You will be told when it is done.",
        @"download_saved": @"Saved",
        @"download_saved_at": @"%@.m4a is in Files, under Albrhi.",
        @"download_failed": @"Not saved",
        @"download_no_audio": @"This track's manifest offers no audio rendition.",
        @"download_no_segments": @"The audio playlist listed no segments.",
        @"download_empty": @"Every segment came back empty.",
        @"download_not_written": @"The file could not be written.",
        @"download_remux_failed": @"The audio was fetched but could not be put in an m4a container.",
        @"downloads_title": @"Downloads",
        @"downloads_empty": @"Nothing saved yet",
        @"downloads_empty_note": @"Play a track and tap the download button. What you save appears here and in Files, under Albrhi.",
        @"downloads_share": @"Share",
        @"downloads_delete": @"Delete",
        @"downloads_delete_title": @"Delete this track?",
        @"cancel": @"Cancel",
        @"download_no_manifest": @"The download badge was found, but this track's player response carries no stream to fetch.",
        @"downloads_keys": @"Buttons seen so far: %@",
    };

    _arTable = @{
        @"title": @"البرهي ليوتيوب ميوزك",
        @"sb_skip": @"تخطّي",
        @"sb_unskip": @"تراجع",
        @"sb_skipped": @"تُخطّي المقطع",
        @"sb_found": @"وُجد مقطع",
        @"download_started": @"جارٍ الحفظ",
        @"dl_confirm_title": @"حفظ هذا المقطع",
        @"dl_confirm_note": @"سمِّه، واختر قسماً يُحفظ فيه. اترك القسم فارغاً ليُحفظ في المكتبة الرئيسية.",
        @"dl_confirm_name": @"الاسم",
        @"dl_confirm_section": @"القسم",
        @"dl_confirm_save": @"حفظ",
        @"download_started_note": @"يجري جلب المقطع، وستُخبَر عند انتهائه.",
        @"download_saved": @"حُفظ",
        @"download_saved_at": @"‏%@.m4a في تطبيق الملفات، داخل مجلد Albrhi.",
        @"download_failed": @"لم يُحفظ",
        @"download_no_audio": @"بيان هذا المقطع لا يعرض تمثيلة صوتية.",
        @"download_no_segments": @"قائمة الصوت لم تذكر أي مقطع.",
        @"download_empty": @"كل المقاطع عادت فارغة.",
        @"download_not_written": @"تعذّرت كتابة الملف.",
        @"download_remux_failed": @"جُلب الصوت ولم يُمكن وضعه في حاوية m4a.",
        @"downloads_title": @"التنزيلات",
        @"downloads_empty": @"لا شيء محفوظ بعد",
        @"downloads_empty_note": @"شغّل مقطعاً واضغط زر التنزيل. ما تحفظه يظهر هنا وفي تطبيق الملفات داخل مجلد Albrhi.",
        @"downloads_share": @"مشاركة",
        @"downloads_delete": @"حذف",
        @"downloads_delete_title": @"حذف هذا المقطع؟",
        @"cancel": @"إلغاء",
        @"download_no_manifest": @"وُجد زرّ التنزيل، لكن استجابة المشغّل لهذا المقطع لا تحمل تيّاراً يُجلب.",
        @"downloads_keys": @"الأزرار التي رُصدت: %@",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SCIBuildTables(); });

    BOOL arabic = [[NSLocale preferredLanguages].firstObject hasPrefix:@"ar"];
    NSString *value = arabic ? _arTable[key] : _enTable[key];
    return value ?: (_enTable[key] ?: key);
}
