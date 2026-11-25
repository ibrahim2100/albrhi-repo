// Instagram: where an instagram.com address lives inside the app. Pure: address and document in, `instagram://…` or null out.
function albrhiDestination(address, doc) {
  "use strict";
  const page = new URL(address);
  if (!["http:", "https:"].includes(page.protocol)) return null;
  if (page.hostname !== "instagram.com" && !page.hostname.endsWith(".instagram.com")) return null;
  if (page.username || page.password || page.port) return null;

  const parts = page.pathname.split("/").filter(Boolean);

  // /<username>. These first segments are pages of the website, not accounts.
  const website = ["about", "accounts", "direct", "explore", "reels", "reel", "p", "tv", "stories", "web", "legal", "privacy", "developer", "challenge", "emails", "session", "share", "oauth", "graphql", "api"];
  if (parts.length === 1 && /^[A-Za-z0-9._]{1,30}$/.test(parts[0]) && !website.includes(parts[0].toLowerCase())) {
    return "instagram://user?username=" + encodeURIComponent(parts[0]);
  }

  // /explore/tags/<tag>
  if (parts.length === 3 && parts[0] === "explore" && parts[1] === "tags") {
    try { return "instagram://tag?name=" + encodeURIComponent(decodeURIComponent(parts[2])); } catch (error) { return null; }
  }

  // /p/<code>, /reel/<code>, /<user>/p/<code>, /<user>/reel/<code>: Instagram writes the app's own address for the post into the page; it is
  // missing while a navigation is still loading, which is normal -- the caller looks again.
  const kind = parts.length === 2 ? parts[0] : (parts.length === 3 ? parts[1] : null);
  if (kind === "p" || kind === "reel") {
    const meta = doc && doc.querySelector ? doc.querySelector("meta[property='al:ios:url']") : null;
    const content = meta ? meta.getAttribute("content") : null;
    if (!content) return null;
    try {
      const native = new URL(content);
      if (native.protocol !== "instagram:" || native.username || native.password || native.port) return null;
      return native.href;
    } catch (error) { return null; }
  }
  return null;
}
if (typeof module !== "undefined") module.exports = { albrhiDestination };
