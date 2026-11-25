// TikTok: where a tiktok.com address lives inside the app. Pure: address and document in, `snssdk1233://…` or null out.
// The short links (vm./vt.tiktok.com/<code>, tiktok.com/t/<code>) redirect to the long address in the browser, and this sees that one.
function albrhiDestination(address, doc) {
  "use strict";
  const page = new URL(address);
  if (!["http:", "https:"].includes(page.protocol)) return null;
  if (page.hostname !== "tiktok.com" && !page.hostname.endsWith(".tiktok.com")) return null;
  if (page.username || page.password || page.port) return null;

  const parts = page.pathname.split("/").filter(Boolean);
  // /@<user>/video/<id> and /@<user>/photo/<id>: a post is a post. (A /<lang>/ prefix, like /en/, is skipped.)
  const at = parts.findIndex((part) => part.startsWith("@"));
  if (at >= 0 && parts.length === at + 3 && (parts[at + 1] === "video" || parts[at + 1] === "photo") && /^\d{8,25}$/.test(parts[at + 2])) {
    return "snssdk1233://aweme/detail/" + parts[at + 2];
  }

  // /@<user>: the app's profile route takes the numeric id, which the page carries in its own data block.
  if (at >= 0 && parts.length === at + 1 && doc && doc.getElementById) {
    const block = doc.getElementById("__UNIVERSAL_DATA_FOR_REHYDRATION__");
    if (!block) return null;
    try {
      const scope = JSON.parse(block.textContent)["__DEFAULT_SCOPE__"] || {};
      const user = ((scope["webapp.user-detail"] || {}).userInfo || {}).user || {};
      const id = String(user.id || "");
      // Only the account whose address this is: a profile page also embeds other people.
      const handle = parts[at].slice(1).toLowerCase();
      if (/^\d{5,25}$/.test(id) && String(user.uniqueId || "").toLowerCase() === handle) return "snssdk1233://user/profile/" + id;
    } catch (error) { return null; }
  }
  return null;
}
if (typeof module !== "undefined") module.exports = { albrhiDestination };
