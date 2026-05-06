// ==UserScript==
// @name        Medium Paywall Bypass
// @namespace   Violentmonkey Scripts
// @run-at      document-start
// @match       *://*.medium.com/*
// @match       *://medium.com/*
// @match       *://*/*
// @grant       none
// @version     3.0
// @inject-into content
// @updateURL   https://gist.githubusercontent.com/mathix420/e0604ab0e916622972372711d2829555/raw/medium.user.js
// @downloadURL https://gist.githubusercontent.com/mathix420/e0604ab0e916622972372711d2829555/raw/medium.user.js
// @website     freedium-mirror.cfd
// @author      Mathix420, ZhymabekRoman
// @description Don't forget to remove `@match` filters you don't want.
// ==/UserScript==

// initCall is telling us if we need to inject the title observer
function mediumRedirecter(initCall = false) {
  if (
      // Allow seeing original articles that were already redirected to freedium.
      !window.location.href.endsWith('#bypass') &&
      // Do not redirect when editing on medium.
      !window.location.href.includes("/edit?source=") &&
      // Detect if we are on a medium website (regardless of the domain)
      document.head?.querySelector('meta[property="al:android:url"]')?.content?.includes('medium://p/')
    ) {
    window.location.href = 'https://freedium-mirror.cfd/' + window.location.href;
  } else if (initCall && /(.*\.|^)medium\.com$/.test(window.location.host)) {
    // Observe <title> changes
    new MutationObserver(function(mutations) {
      // If title change is detected, check if a freedium redirect is required
      if (mutations[0].target.textContent) mediumRedirecter();
    }).observe(
        document.querySelector('title'),
        { subtree: true, characterData: true, childList: true }
    );
  }
}

mediumRedirecter(true);
