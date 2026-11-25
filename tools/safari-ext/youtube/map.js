// YouTube: where a youtube.com / youtu.be address lives inside the app. Pure: address and document in, `youtube://…` or null out.
function albrhiDestination(address, doc) {
  "use strict";
  const page = new URL(address);
  if (!["http:", "https:"].includes(page.protocol)) return null;
  if (page.username || page.password || page.port) return null;
  const host = page.hostname.replace(/^(www\.|m\.)/, "");
  const parts = page.pathname.split("/").filter(Boolean);
  const idPattern = /^[A-Za-z0-9_-]{6,20}$/;
  const base = "youtube://www.youtube.com";

  // The moment inside a video, kept: 90, 90s, 1h2m3s.
  function seconds(value) {
    if (!value) return null;
    if (/^\d+$/.test(value)) return value;
    const match = /^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$/.exec(value);
    if (!match || !(match[1] || match[2] || match[3])) return null;
    return String((+match[1] || 0) * 3600 + (+match[2] || 0) * 60 + (+match[3] || 0));
  }
  function watch(id) {
    if (!idPattern.test(id)) return null;
    const at = seconds(page.searchParams.get("t") || page.searchParams.get("start"));
    const list = page.searchParams.get("list");
    return base + "/watch?v=" + encodeURIComponent(id) + (list ? "&list=" + encodeURIComponent(list) : "") + (at ? "&t=" + at + "s" : "");
  }

  if (host === "youtu.be") return parts.length === 1 ? watch(parts[0]) : null;
  if (host !== "youtube.com") return null;

  if (parts.length === 1 && parts[0] === "watch") return watch(page.searchParams.get("v") || "");
  if (parts.length === 2 && (parts[0] === "shorts" || parts[0] === "live" || parts[0] === "embed")) {
    return parts[0] === "shorts" && idPattern.test(parts[1]) ? base + "/shorts/" + encodeURIComponent(parts[1]) : watch(parts[1]);
  }
  if (parts.length === 1 && parts[0] === "playlist") {
    const list = page.searchParams.get("list");
    return list && /^[A-Za-z0-9_-]{10,60}$/.test(list) ? base + "/playlist?list=" + encodeURIComponent(list) : null;
  }
  // A channel: /@handle, /channel/<id>, /c/<name>, /user/<name>, with or without a tab after it.
  if (parts.length >= 1 && /^@[A-Za-z0-9._-]{3,60}$/.test(parts[0])) return base + "/" + encodeURIComponent(parts[0]).replace("%40", "@");
  if (parts.length >= 2 && ["channel", "c", "user"].includes(parts[0]) && /^[A-Za-z0-9._-]{1,80}$/.test(parts[1])) {
    return base + "/" + parts[0] + "/" + encodeURIComponent(parts[1]);
  }
  return null;
}
if (typeof module !== "undefined") module.exports = { albrhiDestination };
