// Firefox default prefs, applied to every profile via firefox-apply.
// user.js is read on every Firefox start; values cannot be changed
// in about:config. Edit here, re-run firefox-apply, restart Firefox.

// -- Privacy ----------------------------------------------------------------
user_pref("browser.contentblocking.category", "strict");          // Strict tracking protection
user_pref("privacy.globalprivacycontrol.enabled", true);          // Tell websites not to share my data
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.query_stripping.enabled", true);
user_pref("privacy.query_stripping.enabled.pbmode", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.emailtracking.enabled", true);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.speculative-parallel-limit", 0);

// -- Sessions ---------------------------------------------------------------
user_pref("browser.startup.page", 3);                             // Open previous windows and tabs

// -- Passwords & forms ------------------------------------------------------
user_pref("signon.rememberSignons", false);                       // Do not ask to save passwords
user_pref("dom.forms.autocomplete.formautofill", true);

// -- Block AI enhancements --------------------------------------------------
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.smartWindow", "blocked");
user_pref("browser.ai.control.translations", "blocked");
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.page", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("browser.ml.linkPreview.collapsed", true);
user_pref("extensions.ml.enabled", false);

// -- Vertical tabs (sidebar revamp) -----------------------------------------
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", true);
user_pref("sidebar.visibility", "expand-on-hover");

// -- Browsing ---------------------------------------------------------------
user_pref("image.jxl.enabled", true);
user_pref("browser.translations.enable", false);
user_pref("browser.translations.neverTranslateLanguages", "pl");
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);
