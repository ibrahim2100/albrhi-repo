"use strict";
const assert = require("assert");
const path = require("path");
const root = path.join(__dirname, "..");
let checks = 0;
function eq(label, got, want) { checks++; assert.strictEqual(got, want, label + ": got " + got + ", wanted " + want); }

// A document with only what the maps ask of it.
function doc(options) {
  options = options || {};
  return {
    querySelector: (selector) => selector.includes("al:ios:url") && options.meta ? { getAttribute: () => options.meta } : null,
    getElementById: (id) => id === "__UNIVERSAL_DATA_FOR_REHYDRATION__" && options.data ? { textContent: JSON.stringify(options.data) } : null,
  };
}

{
  const m = require(path.join(root, "instagram/map.js")).albrhiDestination;
  eq("ig profile", m("https://www.instagram.com/zuck/", doc()), "instagram://user?username=zuck");
  eq("ig profile dots", m("https://instagram.com/some.name_1", doc()), "instagram://user?username=some.name_1");
  eq("ig website page", m("https://www.instagram.com/explore/", doc()), null);
  eq("ig accounts page", m("https://www.instagram.com/accounts/login/", doc()), null);
  eq("ig tag", m("https://www.instagram.com/explore/tags/cats/", doc()), "instagram://tag?name=cats");
  eq("ig tag arabic", m("https://www.instagram.com/explore/tags/%D9%82%D8%B7%D8%A9/", doc()), "instagram://tag?name=%D9%82%D8%B7%D8%A9");
  eq("ig post with meta", m("https://www.instagram.com/p/ABC123/", doc({ meta: "instagram://media?id=123_456" })), "instagram://media?id=123_456");
  eq("ig reel with meta", m("https://www.instagram.com/reel/ABC123/", doc({ meta: "instagram://media?id=9" })), "instagram://media?id=9");
  eq("ig user post", m("https://www.instagram.com/zuck/p/ABC123/", doc({ meta: "instagram://media?id=9" })), "instagram://media?id=9");
  eq("ig post without meta yet", m("https://www.instagram.com/p/ABC123/", doc()), null);
  eq("ig meta of another scheme", m("https://www.instagram.com/p/ABC123/", doc({ meta: "https://evil.example/" })), null);
  eq("ig other host", m("https://evilinstagram.com/zuck", doc()), null);
  eq("ig credentials", m("https://a:b@www.instagram.com/zuck", doc()), null);
  eq("ig port", m("https://www.instagram.com:444/zuck", doc()), null);
  eq("ig not http", m("ftp://www.instagram.com/zuck", doc()), null);
}
{
  const m = require(path.join(root, "youtube/map.js")).albrhiDestination;
  eq("yt watch", m("https://www.youtube.com/watch?v=dQw4w9WgXcQ", doc()), "youtube://www.youtube.com/watch?v=dQw4w9WgXcQ");
  eq("yt mobile watch with time", m("https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=1m30s", doc()), "youtube://www.youtube.com/watch?v=dQw4w9WgXcQ&t=90s");
  eq("yt watch plain seconds", m("https://youtube.com/watch?v=dQw4w9WgXcQ&t=42", doc()), "youtube://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s");
  eq("yt watch in a list", m("https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL1234567890", doc()), "youtube://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL1234567890");
  eq("yt short link", m("https://youtu.be/dQw4w9WgXcQ?si=abc&t=5", doc()), "youtube://www.youtube.com/watch?v=dQw4w9WgXcQ&t=5s");
  eq("yt shorts", m("https://www.youtube.com/shorts/abcDEF12345", doc()), "youtube://www.youtube.com/shorts/abcDEF12345");
  eq("yt live", m("https://www.youtube.com/live/dQw4w9WgXcQ", doc()), "youtube://www.youtube.com/watch?v=dQw4w9WgXcQ");
  eq("yt playlist", m("https://www.youtube.com/playlist?list=PLabcdefghij123", doc()), "youtube://www.youtube.com/playlist?list=PLabcdefghij123");
  eq("yt handle", m("https://www.youtube.com/@MrBeast", doc()), "youtube://www.youtube.com/@MrBeast");
  eq("yt handle tab", m("https://www.youtube.com/@MrBeast/videos", doc()), "youtube://www.youtube.com/@MrBeast");
  eq("yt channel", m("https://www.youtube.com/channel/UCX6OQ3DkcsbYNE6H8uQQuVA", doc()), "youtube://www.youtube.com/channel/UCX6OQ3DkcsbYNE6H8uQQuVA");
  eq("yt home", m("https://www.youtube.com/", doc()), null);
  eq("yt results", m("https://www.youtube.com/results?search_query=x", doc()), null);
  eq("yt watch no id", m("https://www.youtube.com/watch", doc()), null);
  eq("yt bad id", m("https://www.youtube.com/watch?v=a\"b", doc()), null);
  eq("yt other host", m("https://notyoutube.com/watch?v=dQw4w9WgXcQ", doc()), null);
  eq("yt credentials", m("https://a@www.youtube.com/watch?v=dQw4w9WgXcQ", doc()), null);
}
{
  const m = require(path.join(root, "tiktok/map.js")).albrhiDestination;
  eq("tt video", m("https://www.tiktok.com/@user.name/video/7301234567890123456?is_from_webapp=1", doc()), "snssdk1233://aweme/detail/7301234567890123456");
  eq("tt photo", m("https://www.tiktok.com/@user/photo/7301234567890123456", doc()), "snssdk1233://aweme/detail/7301234567890123456");
  eq("tt lang prefix", m("https://www.tiktok.com/en/@user/video/7301234567890123456", doc()), "snssdk1233://aweme/detail/7301234567890123456");
  eq("tt mobile host", m("https://m.tiktok.com/@user/video/7301234567890123456", doc()), "snssdk1233://aweme/detail/7301234567890123456");
  eq("tt non numeric id", m("https://www.tiktok.com/@user/video/abc", doc()), null);
  eq("tt foryou", m("https://www.tiktok.com/foryou", doc()), null);
  const data = (id, uniqueId) => ({ data: { __DEFAULT_SCOPE__: { "webapp.user-detail": { userInfo: { user: { id, uniqueId } } } } } });
  eq("tt profile", m("https://www.tiktok.com/@SomeOne", doc(data("6812345678901234567", "someone"))), "snssdk1233://user/profile/6812345678901234567");
  eq("tt profile of another account embedded", m("https://www.tiktok.com/@someone", doc(data("6812345678901234567", "other"))), null);
  eq("tt profile without data", m("https://www.tiktok.com/@someone", doc()), null);
  eq("tt profile bad id", m("https://www.tiktok.com/@someone", doc(data("12", "someone"))), null);
  eq("tt other host", m("https://nottiktok.com/@user/video/7301234567890123456", doc()), null);
}
console.log("safari-ext maps: " + checks + " checks passed");
