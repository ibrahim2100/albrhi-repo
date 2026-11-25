// Albrhi — Open in app. The part every app shares: ask the page's own map (`albrhiDestination`, defined by map.js beside this file) where the
// address in the tab lives inside the app, and go there once. Safari loads these two files into one world, in this order.
(() => {
  "use strict";
  if (window.top !== window) return;

  let handedOff = null;   // "<address>\n<destination>" of the last hand-off, so a tab that stays on the same page is sent once, not on every look

  function look() {
    if (document.visibilityState !== "visible") return;
    let destination = null;
    try {
      destination = albrhiDestination(window.location.href, document);
    } catch (error) {
      return;   // a page that changed shape costs the hand-off, never the page
    }
    if (!destination) return;
    const key = window.location.pathname + "\n" + destination;
    if (key === handedOff) return;
    handedOff = key;
    window.location.href = destination;
  }

  // The sites change address without loading a new page, and publish what the app needs (a meta tag, a JSON block) a moment after that: so look
  // again, cheaply, on a timer, whenever the tab is in front. `look` does nothing until it has an answer and nothing twice.
  window.setInterval(look, 700);
  document.addEventListener("visibilitychange", look);
  look();
})();
