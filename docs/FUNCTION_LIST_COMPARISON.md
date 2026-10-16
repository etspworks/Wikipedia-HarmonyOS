# Wikipedia function list comparison: iOS vs HarmonyOS

- **Source:** Wikipedia for iOS, release of 11 August 2026, build 6144 (upstream tag `releases/2026.08.11`), 1027 functions.
- **Target:** Wikipedia for HarmonyOS (`etspworks/Wikipedia-HarmonyOS` main `3d9029d`), 600 functions.
- Both function lists were extracted from each app's source code.
- ✅ = the function is in that app's function list, ❌ = it is not.
- The function text comes from the iOS list, or from the HarmonyOS list when iOS lacks it.
- 1122 rows: 490 in both, 537 iOS only, 95 HarmonyOS only.
- A note with #N points to the row whose function gives the same result.

| # | Function | iOS | HarmonyOS | Notes |
|---:|---|:---:|:---:|---|
| 1 | `Explore` Tap the Wikipedia logo to scroll the Explore feed to the top | ✅ | ✅ |  |
| 2 | `Explore` Tap the status bar to scroll the Explore feed to the top and show the navigation bar | ✅ | ❌ | Not in the HarmonyOS function list. |
| 3 | `Explore` Swipe down on the feed to refresh the Explore feed | ✅ | ✅ |  |
| 4 | `Explore` Tap Dismiss on the reading list sync promo to hide it permanently | ❌ | ✅ | HarmonyOS-only reading list sync promo card in the Explore feed. |
| 5 | `Explore` Tap Log in to sync your saved articles to open the login page | ❌ | ✅ | HarmonyOS-only reading list sync promo card in the Explore feed. |
| 6 | `Explore` Swipe up near the end of the feed to load the previous day's cards | ✅ | ❌ | HarmonyOS does not load earlier days' cards at the end of the feed. |
| 7 | `Explore` Tap the three-dot overflow button on a card header to open the card overflow menu | ✅ | ✅ |  |
| 8 | `Explore` Select the Customize accessibility action on a card to open feed customization | ✅ | ✅ | HarmonyOS reaches feed customization through the card options sheet; no accessibility action, #204. |
| 9 | `Explore` Tap a feed article card to open the article | ✅ | ✅ |  |
| 10 | `Explore` Tap a Top read article row in the Top read card | ✅ | ✅ |  |
| 11 | `Explore` Tap the Random article card to open a random article | ✅ | ✅ | HarmonyOS lists all hero article cards in one row, #9. |
| 12 | `Explore` Tap the Because you read card | ✅ | ✅ | HarmonyOS lists all hero article cards in one row, #9. |
| 13 | `Explore` Tap a related article row in the Because you read card | ✅ | ✅ |  |
| 14 | `Explore` Tap the Featured article card | ✅ | ✅ | HarmonyOS lists all hero article cards in one row, #9. |
| 15 | `Explore` Tap the Continue reading card | ✅ | ✅ | HarmonyOS lists all hero article cards in one row, #9. |
| 16 | `Explore` Tap the Picture of the day card to open the image viewer | ✅ | ✅ |  |
| 17 | `Explore` Long press a feed card to open the article peek preview | ✅ | ❌ | HarmonyOS has no long-press article peek preview here. |
| 18 | `Explore` Toggle Save for later on an article card to save or unsave the article | ✅ | ✅ |  |
| 19 | `Explore` Tap Another random article on the random card to load another random article | ✅ | ✅ | HarmonyOS lists all card footer links in one row. |
| 20 | `Explore` Tap Additional related articles to open the Because You Read page | ✅ | ✅ | HarmonyOS lists all card footer links in one row. |
| 21 | `Explore` Tap All top read articles to open the Top Read page | ✅ | ✅ | HarmonyOS lists all card footer links in one row. |
| 22 | `Explore` Tap the Randomizer dice button to roll the dice animation | ✅ | ✅ | HarmonyOS Randomizer loads another random article; no dice animation listed, #161. |
| 23 | `Explore` Tap the Add an image card | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 24 | `Explore` Tap Safari in the system status-bar breadcrumb to return to Safari | ✅ | ❌ | iOS system breadcrumb back to Safari; not an app function on HarmonyOS. |
| 25 | `Explore` Tap Undo to restore the hidden card | ✅ | ✅ |  |
| 26 | `Explore` Tap Manage preferences on the reading preferences card | ✅ | ❌ | Not in the HarmonyOS function list. |
| 27 | `Explore` Tap the action button on the announcement card | ✅ | ✅ |  |
| 28 | `Explore` Tap the dismiss button on the announcement card to dismiss it | ✅ | ✅ |  |
| 29 | `Explore` Tap Turn on push notifications on the notifications card | ✅ | ❌ | Not in the HarmonyOS function list. |
| 30 | `Explore` Tap N more historical events on this day to open the On This Day page | ✅ | ✅ | HarmonyOS lists all card footer links in one row. |
| 31 | `Explore` Tap an event row on the On this day card | ✅ | ✅ |  |
| 32 | `Explore` Tap the Which came first? game card to open the game splash | ✅ | ✅ |  |
| 33 | `Explore` Tap Play today's game to start the game | ✅ | ✅ | HarmonyOS opens the games splash first rather than starting the game directly, #32. |
| 34 | `Explore` Tap Continue today's game to resume the game in progress | ✅ | ✅ | HarmonyOS card opens the splash, whose play button continues today's game, #32, #209. |
| 35 | `Explore` Tap Review results on the completed game card | ✅ | ✅ | HarmonyOS card opens the splash, whose play button shows Review results, #32, #209. |
| 36 | `Explore` Tap Play the archive on the completed game card to open the archive | ✅ | ❌ | HarmonyOS has no game archive. |
| 37 | `Home` Tap the Wikipedia logo to scroll the selected feed to the top | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 38 | `Home` Tap the current language name to open the language picker menu | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 39 | `Home` Tap the More options button to open the more options menu | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 40 | `Home` Tap a For You card to open the article | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 41 | `Home` Tap the new interests link on the That's it for today! card to open interests customization | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 42 | `Home` Tap the community link on the That's it for today! card to switch to the Community segment | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 43 | `App Shell` Tap Back to return to the previous screen | ✅ | ✅ | HarmonyOS lists the Back button separately on each screen, #163. |
| 44 | `Explore > Article > Disambiguation` Tap a similar page row to open that article | ❌ | ✅ | iOS function list has no row for tapping a similar page in the disambiguation list. |
| 45 | `Explore > In the News` Tap an article link in a news story to open the article | ❌ | ✅ | iOS lists only the long-press peek for In the news articles, not a tap. |
| 46 | `App Shell` Tap Profile to open the Profile | ✅ | ✅ |  |
| 47 | `Search` Tap the Search Wikipedia field to activate search | ❌ | ✅ | Focusing the search field is part of typing a search in the iOS list. |
| 48 | `App Shell` Tap Tabs to open the article tabs overview | ✅ | ✅ | HarmonyOS lists the Tabs button separately on each screen. |
| 49 | `App Shell` Tap Search to open the search view | ✅ | ✅ | HarmonyOS lists the Search button separately on each screen. |
| 50 | `App Shell` Tap the Wikipedia title to return to Explore or Saved | ✅ | ✅ | HarmonyOS always returns to Explore. |
| 51 | `App Shell` Tap Explore tab to show the Explore feed | ✅ | ✅ |  |
| 52 | `App Shell` Tap Places tab to show Places | ✅ | ✅ |  |
| 53 | `App Shell` Tap Saved tab to show Saved | ✅ | ✅ |  |
| 54 | `App Shell` Tap Activity tab to show Activity | ✅ | ✅ |  |
| 55 | `App Shell` Tap Search tab to show Search and focus the search field | ✅ | ✅ |  |
| 56 | `App Shell` Tap the selected tab again to scroll the Main feed to top or focus Search | ✅ | ❌ | HarmonyOS scrolls to top via the Wikipedia logo; tab reselect is not listed. |
| 57 | `App Shell` Tap Settings tab to show Settings | ✅ | ✅ |  |
| 58 | `App Shell` Tap the Home tab to show the Home feed | ✅ | ❌ | No Home tab in HarmonyOS; only Home feed settings exist. |
| 59 | `App Shell` Tap the plus icon on the reading list prompt toast to add the article to a reading list | ✅ | ✅ | HarmonyOS opens the add-to-list page by tapping the whole toast. |
| 60 | `App Shell` Tap See reading list on the article-added toast to open the reading list | ✅ | ❌ | Not in the HarmonyOS function list. |
| 61 | `App Shell` Tap the article-added toast to open the reading list | ✅ | ❌ | Not in the HarmonyOS function list. |
| 62 | `App Shell` Tap the temporary account toast, including its Learn more. text, to open the account expiry page | ✅ | ❌ | Not in the HarmonyOS function list. |
| 63 | `App Shell` Tap a push notification banner to open the Notifications Center | ✅ | ❌ | Not in the HarmonyOS function list. |
| 64 | `App Shell` Tap the toast to run its action | ✅ | ✅ | HarmonyOS lists only the hint's action button, #65. |
| 65 | `App Shell` Tap the toast action button to run its action | ✅ | ✅ |  |
| 66 | `App Shell` Swipe down on the toast to dismiss it | ✅ | ❌ | Not in the HarmonyOS function list. |
| 67 | `App Shell` Tap the empty state button to run its action | ✅ | ❌ | Not in the HarmonyOS function list. |
| 68 | `Places` Tap Filter to open the filter menu | ✅ | ✅ |  |
| 69 | `Places` Type in Search Places to search for places | ✅ | ✅ |  |
| 70 | `Places` Tap the clear button in the Search Places field to clear the typed text | ❌ | ✅ | Clear button in the Places search field; not in the iOS function list. |
| 71 | `Places` Tap Map to show places as a map | ✅ | ✅ |  |
| 72 | `Places` Tap List to show places as a list | ✅ | ✅ |  |
| 73 | `Places` Tap a root tab bar item to switch to that tab | ❌ | ✅ | HarmonyOS repeats the root tab bar on each screen; iOS lists each tab once under App Shell. |
| 74 | `Places` Drag the map to pan it | ❌ | ✅ | iOS function list does not itemise this Places map or list interaction. |
| 75 | `Places` Pinch the map to zoom it | ❌ | ✅ | iOS function list does not itemise this Places map or list interaction. |
| 76 | `Places` Tap empty map space to clear the selected place | ❌ | ✅ | iOS function list does not itemise this Places map or list interaction. |
| 77 | `Places` Tap Results in this area to search the visible map area | ✅ | ✅ |  |
| 78 | `Places` Tap the Did you mean suggestion to run the corrected search | ✅ | ✅ |  |
| 79 | `Places` Tap a suggestion that has coordinates to recentre the map on that place and save it to recent searches | ❌ | ✅ | iOS function list has no row for tapping a place completion suggestion. |
| 80 | `Places` Tap a suggestion without coordinates to open the article | ❌ | ✅ | iOS function list has no row for tapping a place completion suggestion. |
| 81 | `Places` Tap the Nearby matching row to run a term search for the typed text | ❌ | ✅ | iOS function list has no row for the Nearby matching suggestion. |
| 82 | `Places` Tap Recenter on your location to center the map on the user | ✅ | ✅ |  |
| 83 | `Places` Tap an article marker on the map | ✅ | ✅ |  |
| 84 | `Places` Tap Show more articles in a place callout | ✅ | ✅ | HarmonyOS zooms in when a cluster pin is tapped instead of a callout button. |
| 85 | `Places` Tap Legal to open the map provider attribution | ✅ | ✅ | HarmonyOS shows the map attribution link only in Settings > About, not on the map. |
| 86 | `App Shell > Profile > Settings > About` Tap Send app feedback to open the feedback link | ❌ | ✅ | iOS About is a web page; its links are not listed as functions. |
| 87 | `App Shell > Profile > Settings > About` Tap Wikimedia Foundation to open wikimediafoundation.org in the in-app web page | ❌ | ✅ | iOS About is a web page; its links are not listed as functions. |
| 88 | `Search` Type in Search Wikipedia to search for articles | ✅ | ✅ |  |
| 89 | `Search` Tap the search within articles card | ✅ | ❌ | Not in the HarmonyOS function list. |
| 90 | `Search` Tap the info button on the search within articles card | ✅ | ❌ | Not in the HarmonyOS function list. |
| 91 | `Search` Tap the hide button on the search within articles card | ✅ | ❌ | Not in the HarmonyOS function list. |
| 92 | `Search` Tap Back on the iPad search bar | ✅ | ✅ | iPad-only button; HarmonyOS uses the close icon beside the search field. |
| 93 | `Search` Tap Clear on the iPad search bar to clear the text | ✅ | ✅ | iPad-only button; HarmonyOS has a clear icon inside the search field. |
| 94 | `Search` Tap a language button to set the search content language | ✅ | ✅ |  |
| 95 | `Search` Tap More to open the preferred languages screen | ✅ | ✅ |  |
| 96 | `Search` Tap the language selector bar to open the language picker | ✅ | ✅ | HarmonyOS opens language choice through More in the language bar, #95. |
| 97 | `Search` Tap a root tab bar item to switch to that tab | ❌ | ✅ | HarmonyOS repeats the root tab bar on each screen; iOS lists each tab once under App Shell. |
| 98 | `Saved` Tap More to open the Saved menu with Sort and Edit | ✅ | ✅ |  |
| 99 | `Saved` Tap All articles to show the saved articles scope | ✅ | ✅ |  |
| 100 | `Saved` Tap Reading lists to show the reading lists scope | ✅ | ✅ |  |
| 101 | `Saved` Tap a root tab bar item to switch to that tab | ❌ | ✅ | HarmonyOS repeats the root tab bar on each screen; iOS lists each tab once under App Shell. |
| 102 | `Saved` Tap Cancel to exit edit mode and restore More and Profile buttons | ✅ | ✅ | HarmonyOS labels the button Done. |
| 103 | `Saved` Tap Add to list to open Add To Reading List for the selected saved articles | ✅ | ✅ |  |
| 104 | `Saved` Tap Unsave to remove the selected articles from saved | ✅ | ✅ |  |
| 105 | `Activity` Tap More to open the Activity menu | ✅ | ✅ |  |
| 106 | `Activity` Tap the Articles read this month card | ✅ | ✅ |  |
| 107 | `Activity` Tap the Articles saved this month card | ✅ | ✅ |  |
| 108 | `Activity` Tap the Total edits across projects card | ✅ | ❌ | Not in the HarmonyOS function list. |
| 109 | `Activity` Tap the Contributions this month card | ✅ | ✅ |  |
| 110 | `Activity` Tap a read article row in the timeline to open the article | ✅ | ✅ |  |
| 111 | `Activity` Long press a read article row to open the row context menu | ✅ | ❌ | HarmonyOS timeline rows have no long-press menu. |
| 112 | `Activity` Tap a saved article row in the timeline to open the article | ✅ | ❌ | HarmonyOS timeline lists reading history only. |
| 113 | `Activity` Tap an edited row in the timeline to open the edit | ✅ | ❌ | HarmonyOS timeline lists reading history only. |
| 114 | `Activity` Tap View changes on an edited row to open the edit | ✅ | ❌ | HarmonyOS timeline lists reading history only. |
| 115 | `Activity` Swipe a timeline row and tap Delete | ✅ | ❌ | Not in the HarmonyOS function list. |
| 116 | `Activity` Tap Explore Wikipedia to open Explore | ✅ | ❌ | Not in the HarmonyOS function list. |
| 117 | `Activity` Tap Get started on the Year in Review card to open Year in Review | ✅ | ✅ | HarmonyOS opens Year in Review from the Profile sheet, not an Activity card, #274. |
| 118 | `Activity` Tap Close history notice card to dismiss the notice | ✅ | ❌ | Not in the HarmonyOS function list. |
| 119 | `Temporary Account` Tap Log in or create account to start login | ✅ | ❌ | HarmonyOS temporary account page has no login button; login is under Settings. |
| 120 | `Temporary Account` Tap the navigation bar close button to dismiss the screen | ✅ | ✅ | HarmonyOS uses a Back chevron instead of a close button. |
| 121 | `Temporary Account` Tap Talk page to open the temporary account talk page | ✅ | ✅ |  |
| 122 | `Temporary Account` Tap End session to open the exit session alert | ✅ | ✅ |  |
| 123 | `Temporary Account` Tap Read more on the temporary account toast | ✅ | ✅ | HarmonyOS offers Read more in a Create Account banner, not a toast. |
| 124 | `App Shell > Profile > Log In > Two-Factor Login` Tap Cancel (X icon) to close the Two-Factor Login page | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 125 | `Welcome` Swipe between the welcome pages | ✅ | ✅ |  |
| 126 | `Welcome` Tap Next to advance to the next welcome page | ✅ | ✅ |  |
| 127 | `Welcome` Tap Skip to dismiss the welcome flow | ✅ | ✅ |  |
| 128 | `App Onboarding` Tap Skip to apply the default feed preference and finish onboarding | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 129 | `App Onboarding` Tap Next to advance to the next onboarding step | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 130 | `Widgets` Long press the app icon to open the home screen quick actions | ✅ | ❌ | iOS home-screen quick actions; the HarmonyOS port defines no app shortcuts. |
| 131 | `Global` Open the wikipedia://explore link to launch the Explore screen | ✅ | ❌ | HarmonyOS registers no wikipedia:// link scheme. |
| 132 | `Global` Tap an https://[site]/wiki/[page_id] link in another app to open the article in the app | ✅ | ✅ |  |
| 133 | `Global` Tap a wikipedia://[site]/wiki/[page_id] link to open the article in the app | ✅ | ❌ | HarmonyOS registers no wikipedia:// link scheme. |
| 134 | `Global` Tap the Random article shortcut to open a random article | ✅ | ❌ | iOS home-screen quick action; HarmonyOS declares no app shortcuts. |
| 135 | `Global` Reopen the app to restore the last article scroll position | ✅ | ✅ | HarmonyOS resumes a backgrounded app in place; scroll restore after relaunch is not listed. |
| 136 | `Global` Switch the device between light and dark appearance to make the app follow it under the Default theme | ❌ | ✅ | System appearance following; the iOS list does not count it as a function. |
| 137 | `Global` Relaunch the app to restore the previously chosen theme | ❌ | ✅ | Theme persistence across launches; the iOS list does not count it as a function. |
| 138 | `Global` Open the wikipedia://places link to show Places, optionally with an article | ✅ | ❌ | HarmonyOS registers no wikipedia:// link scheme. |
| 139 | `Global` Open the wikipedia://saved link to show the Saved tab | ✅ | ❌ | HarmonyOS registers no wikipedia:// link scheme. |
| 140 | `Global` Open a shared reading list link to import it and open the imported list | ✅ | ❌ | Not in the HarmonyOS function list. |
| 141 | `Global` Tap a wikipedia:// link to route to the matching tab, search, history or content | ✅ | ✅ | HarmonyOS routes links by a targetPage parameter, not wikipedia:// URLs. |
| 142 | `Explore > Add To Reading List` Tap Create new list to open the Create Reading List screen | ✅ | ✅ |  |
| 143 | `Explore > Add To Reading List` Tap a reading list row to add the selected articles to that list | ✅ | ✅ |  |
| 144 | `Explore > Article` Tap the lead image to open the Image Gallery | ✅ | ❌ | HarmonyOS shows the lead image but tapping it does nothing. |
| 145 | `Explore > Article` Long press the lead image to open the lead image gallery preview | ✅ | ❌ | HarmonyOS has no lead image preview on long press. |
| 146 | `Explore > Article` Swipe down on the article to refresh it | ✅ | ❌ | HarmonyOS article has no pull-to-refresh; Try again reloads only after an error. |
| 147 | `Explore > Article` Swipe the article to the top to reveal the navigation bar | ✅ | ❌ | Not in the HarmonyOS function list. |
| 148 | `Explore > Article` Tap an inline article link to open the linked article | ✅ | ✅ |  |
| 149 | `Explore > Article` Tap an external link inside an article table, figure or pie legend to open it in the single-page web view | ❌ | ✅ | iOS function list does not separate external links from article links. |
| 150 | `Explore > Article` Tap an external link in the article body to open it in the single-page web view | ❌ | ✅ | iOS function list does not separate external links from article links. |
| 151 | `Explore > Article` Long press an inline article link to open the link preview and context menu | ✅ | ❌ | HarmonyOS has no long-press preview or context menu on article links. |
| 152 | `Explore > Article` Tap a citation marker to open the reference popover | ✅ | ✅ |  |
| 153 | `Explore > Article` Tap an inline article image to open the Image Gallery at that image | ✅ | ❌ | HarmonyOS article images do not open the Image Gallery. |
| 154 | `Explore > Article` Tap + Add article description to open the title and description editor | ✅ | ✅ | HarmonyOS has no Add description link; the description is edited from the edit menu, #473. |
| 155 | `Explore > Article` Tap Edit section (pencil) to open the section editor or the title and description editor | ✅ | ✅ | HarmonyOS opens an edit menu offering description or section editing. |
| 156 | `Explore > Article` Tap Try again to reload the article | ❌ | ✅ | Article load error retry; not in the iOS function list. |
| 157 | `Explore > Article` Tap Edit section on a protected page (pencil with lock) | ✅ | ✅ | HarmonyOS shows the padlock pencil but opens the normal edit menu, #155. |
| 158 | `Explore > Article` Tap Quick facts (Expand table) to expand or collapse the infobox table | ✅ | ✅ |  |
| 159 | `Explore > Article` Tap Expand section to expand or collapse a collapsible section | ✅ | ✅ |  |
| 160 | `Explore > Article` Tap the embedded map in the article | ✅ | ❌ | Not in the HarmonyOS function list. |
| 161 | `Explore > Article` Tap the Randomizer (dice) button to open a random article | ✅ | ✅ |  |
| 162 | `Explore > Article` Drag the article to dismiss an open reference popover | ✅ | ❌ | Not in the HarmonyOS function list. |
| 163 | `Explore > Article` Tap Back to return to the previous screen | ✅ | ✅ |  |
| 164 | `Explore > Random Article` Tap Listen to pronunciation to open the pronunciation link in the web view | ❌ | ✅ | Pronunciation button on the Random Article screen; the iOS list has no pronunciation row. |
| 165 | `Explore > Article` Tap the W (Wikipedia logo) to return to the tab the article was started from | ✅ | ✅ | HarmonyOS always returns to Explore, not to the tab the article came from, #50. |
| 166 | `Explore > Article` Tap the < Safari back link to return to the app the article was opened from | ✅ | ❌ | iOS system back-to-app link; HarmonyOS has no equivalent. |
| 167 | `Explore > Article` Tap Table of contents to show the table of contents | ✅ | ✅ |  |
| 168 | `Explore > Article` Tap Change language to open the Languages list | ✅ | ✅ |  |
| 169 | `Explore > Article` Tap Save for later to save or unsave the article | ✅ | ✅ |  |
| 170 | `Explore > Article` Long press Save for later to open Add to reading list | ✅ | ✅ |  |
| 171 | `Explore > Article` Tap Find in page to open the find-in-page bar | ✅ | ✅ |  |
| 172 | `Explore > Article` Tap Font size (tT) to open the reading themes popover | ✅ | ✅ |  |
| 173 | `Explore > Article` Tap Share in the article toolbar to open the share sheet | ✅ | ✅ | HarmonyOS offers Share from the More menu, not the toolbar, #535. |
| 174 | `Explore > Article` Tap More (three dots) to open the More menu | ✅ | ✅ |  |
| 175 | `Explore > Article` Tap Listen to pronunciation to open the pronunciation link in the single-page web view | ❌ | ✅ | Pronunciation button; not in the iOS function list. |
| 176 | `Explore > Article` Tap View article in browser to open the article in the browser | ✅ | ✅ |  |
| 177 | `Explore > Article` Tap CC BY-SA 4.0 to open the license page | ✅ | ✅ |  |
| 178 | `Explore > Article` Tap View talk page to open the article talk page | ✅ | ✅ |  |
| 179 | `Explore > Article` Tap View edit history to open the page history | ✅ | ✅ |  |
| 180 | `Explore > Article` Tap View on a map to open the article location in Places | ✅ | ✅ |  |
| 181 | `Explore > Article` Tap a Read more related article row | ✅ | ✅ |  |
| 182 | `Explore > Article` Tap Disambiguation in the article footer to open the Disambiguation Pages list | ✅ | ✅ | HarmonyOS labels the footer link Similar pages. |
| 183 | `Explore > Article` Tap Page issues in the article footer to open the Page Issues Sheet | ✅ | ✅ |  |
| 184 | `Explore > Article` Tap Donate on the fundraising banner to start the donate flow | ✅ | ✅ | HarmonyOS shows the fundraising announcement in Explore, not on articles. Donate opens the web page. |
| 185 | `Explore > Article` Tap Maybe later (or Remind me later) on the fundraising banner | ✅ | ✅ | HarmonyOS shows the fundraising announcement in Explore, not on articles. |
| 186 | `Explore > Article` Tap I already donated on the fundraising banner to hide it and show a thank-you toast | ✅ | ❌ | HarmonyOS fundraising announcement has no I already donated option. |
| 187 | `Explore > Article` Tap Donor policy on the fundraising banner to open the policy page in the browser | ✅ | ❌ | HarmonyOS fundraising announcement has no Donor policy link. |
| 188 | `Explore > Article` Tap Close on the fundraising banner to dismiss it | ✅ | ✅ | HarmonyOS shows the fundraising announcement in Explore, not on articles. |
| 189 | `Explore > Article` Tap Modify in the donation reminders toast to open the donation reminder settings | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 190 | `Explore > Article` Tap Yes, donate now to start the donate flow | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 191 | `Explore > Article` Tap Not now to remove the card and show the reminders toast | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 192 | `Explore > Article` Tap Give monthly to start the donate flow with monthly preselected | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 193 | `Explore > Article` Tap No thanks to remove the wrap-up card | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 194 | `Explore > Article` Tap Learn more to open the experiment help page | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 195 | `Explore > Article` Tap Share feedback to open the donation reminders survey | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 196 | `Explore > Article` Tap View Watchlist in the toast to open the site watchlist | ✅ | ❌ | HarmonyOS watch confirmation has no View Watchlist action. |
| 197 | `Explore > Article Peek Menu` Tap Read more in the peek actions to open the article | ✅ | ❌ | Not in the HarmonyOS function list. |
| 198 | `Explore > Article Peek Menu` Tap Save in the peek actions to save or unsave the article | ✅ | ❌ | Not in the HarmonyOS function list. |
| 199 | `Explore > Because You Read` Tap the Back button to return to the Explore feed | ✅ | ✅ |  |
| 200 | `Explore > Because You Read` Tap a related article row | ✅ | ✅ |  |
| 201 | `Explore > Because You Read` Tap Back to Explore feed to return to the Explore feed | ✅ | ✅ | HarmonyOS uses the Back button; no Back to Explore feed button listed, #199. |
| 202 | `Explore > Card Overflow Menu` Tap Hide this card to hide the card with an undo placeholder | ✅ | ✅ |  |
| 203 | `Explore > Card Overflow Menu` Tap Hide all cards of this type to hide every card of that kind | ✅ | ✅ |  |
| 204 | `Explore > Card Overflow Menu` Tap Customize Explore feed to open the Explore feed settings | ✅ | ✅ |  |
| 205 | `Explore > Card Overflow Menu` Tap Cancel to dismiss the card overflow menu | ✅ | ✅ |  |
| 206 | `Explore > Card Overflow Menu` Tap outside the popover to dismiss the card overflow menu | ✅ | ❌ | Not in the HarmonyOS function list. |
| 207 | `Explore > Games Announcement Alert` Tap Play on the Play “Which came first?” alert to start the game | ✅ | ✅ | HarmonyOS shows this as an in-article invite sheet that opens the games splash, #501. |
| 208 | `Explore > Games Announcement Alert` Tap No thanks on the Play “Which came first?” alert to dismiss it | ✅ | ✅ |  |
| 209 | `Explore > Games Splash` Tap Play today's game to start the game | ✅ | ✅ |  |
| 210 | `Explore > Games Splash` Tap About this game | ✅ | ✅ |  |
| 211 | `Explore > Games Splash` Tap Close to dismiss the Games splash | ✅ | ✅ |  |
| 212 | `Explore > Games Splash` Tap the More button to open the More menu | ✅ | ✅ |  |
| 213 | `Explore > Image Recommendations` Tap the recommended image to open the image gallery | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 214 | `Explore > Image Recommendations` Tap View article to open the recommended article | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 215 | `Explore > Image Recommendations` Tap the image link to open the Commons page in-app | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 216 | `Explore > In the News` Long press a news article to open the article peek preview | ✅ | ❌ | HarmonyOS has no long-press article peek preview here. |
| 217 | `Explore > On This Day` Tap the Back chevron to return to the Explore feed | ✅ | ✅ |  |
| 218 | `Explore > On This Day` Tap a timeline year entry | ✅ | ❌ | Not in the HarmonyOS function list. |
| 219 | `Explore > On This Day` Tap a related article card in an event's carousel | ✅ | ✅ |  |
| 220 | `Explore > On This Day` Long press a related article card to open the article peek preview | ✅ | ❌ | HarmonyOS has no long-press article peek preview here. |
| 221 | `Explore > Search Widget Announcement` Tap Got it on the New Search widget available announcement | ✅ | ❌ | iOS Search widget announcement; the HarmonyOS port has no widgets. |
| 222 | `Explore > Top Read` Tap a Top read article row | ✅ | ✅ |  |
| 223 | `Explore > Top Read` Tap Back to Explore feed to return to the Explore feed | ✅ | ✅ | HarmonyOS uses the Back button; no Back to Explore feed button listed, #199. |
| 224 | `Explore > Which Came First` Tap Close to dismiss the Which came first splash | ✅ | ✅ |  |
| 225 | `Explore > Which Came First` Tap the More button in the navigation bar | ✅ | ✅ |  |
| 226 | `Explore > Which Came First` Tap About this game to open the game's web page | ✅ | ✅ |  |
| 227 | `Explore > Image Gallery` Swipe horizontally on the photo viewer to move between images | ❌ | ✅ | iOS function list has no row for swiping between gallery images. |
| 228 | `Explore > Which Came First` Tap the report-a-problem entry to open a prefilled issue email | ✅ | ✅ |  |
| 229 | `Explore > Year in Review Announcement` Tap the action on the Year in Review announcement to start Year in Review | ✅ | ✅ | HarmonyOS starts Year in Review from the Profile sheet; no Explore announcement, #274. |
| 230 | `Explore > Year in Review Announcement` Tap the decline action on the Year in Review announcement to dismiss it | ✅ | ❌ | HarmonyOS has no Year in Review announcement in Explore. |
| 231 | `Home > Community Feed` Tap See past community content | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 232 | `Home > Empty Feed` Tap Manage modules to open home feed customization | ✅ | ✅ | HarmonyOS opens home feed settings only from Settings; no Home tab. |
| 233 | `App Shell > Profile > Settings` Tap For you to open the home feed settings page | ❌ | ✅ | iOS function list has no Settings row opening the home feed settings. |
| 234 | `Home > Empty Feed` Tap Customize interests on the empty For You state | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 235 | `Home > Empty Feed` Tap Customize community feed on the empty Community state | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 236 | `Home > For You Error State` Tap Try again to retry loading the For You feed | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 237 | `Home > For You Module` Swipe the card carousel horizontally to move between cards | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 238 | `Home > For You Module` Select the Next module accessibility action to move to the next module | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 239 | `Home > For You Module` Select the Previous module accessibility action to move to the previous module | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 240 | `Home > Language Picker Menu` Select a language to switch the Home feed language | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 241 | `Home > Language Picker Menu` Tap Add or edit languages to edit languages | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 242 | `Home > More Options Menu` Tap Save or Unsave to toggle saving the card's article | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 243 | `Home > More Options Menu` Tap Share to share the card | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 244 | `Home > More Options Menu` Tap Hide this card to hide the card | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 245 | `Home > More Options Menu` Tap Hide module to hide the For You module | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 246 | `Home > More Options Menu` Tap Customize interests to open interests customization | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 247 | `App Shell > Education Panel` Tap Close to dismiss the education panel | ✅ | ❌ | Not in the HarmonyOS function list. |
| 248 | `App Shell > Education Panel` Tap the overlay outside the education panel to dismiss it | ✅ | ❌ | Not in the HarmonyOS function list. |
| 249 | `App Shell > Education Panel` Tap the primary button to run the panel action | ✅ | ✅ | HarmonyOS lists only specific panels, such as Enable Location, #294. |
| 250 | `App Shell > Education Panel` Tap the secondary button to run the panel secondary action | ✅ | ✅ | HarmonyOS lists only specific panels, such as Enable Location, #295. |
| 251 | `App Shell > Education Panel` Tap the optional button to run the panel optional action | ✅ | ❌ | Not in the HarmonyOS function list. |
| 252 | `App Shell > Feature Announcement` Tap Close to dismiss the feature announcement | ✅ | ❌ | Not in the HarmonyOS function list. |
| 253 | `App Shell > Feature Announcement` Tap the primary button to run the announcement action | ✅ | ❌ | Not in the HarmonyOS function list. |
| 254 | `App Shell > Generic Alert` Tap OK to dismiss the alert | ✅ | ✅ | HarmonyOS lists OK only on specific dialogs. |
| 255 | `App Shell > Home Onboarding Sheet` Tap Customize my feed to dismiss the sheet and start feed onboarding | ✅ | ❌ | Not in the HarmonyOS function list. |
| 256 | `App Shell > Home Onboarding Sheet` Tap Set it up for me to apply the default feed and dismiss the sheet | ✅ | ❌ | Not in the HarmonyOS function list. |
| 257 | `App Shell > Keep Saved Articles Alert` Tap Yes, keep articles on device to keep local lists and disable sync | ✅ | ❌ | Not in the HarmonyOS function list. |
| 258 | `App Shell > Keep Saved Articles Alert` Tap No, delete articles from device to delete the local lists | ✅ | ❌ | Not in the HarmonyOS function list. |
| 259 | `App Shell > Language Variant Alert` Tap Got it to show the next language variant alert | ✅ | ❌ | Not in the HarmonyOS function list. |
| 260 | `App Shell > Language Variant Alert` Tap Review your preferences to open Preferred Languages | ✅ | ❌ | Not in the HarmonyOS function list. |
| 261 | `App Shell > Language Variant Alert` Tap No thanks to dismiss the language variant alert | ✅ | ❌ | Not in the HarmonyOS function list. |
| 262 | `App Shell > Loading Animation` Tap Cancel to cancel the loading | ✅ | ❌ | Not in the HarmonyOS function list. |
| 263 | `App Shell > Logged Out Alert` Tap Log back in to your account to open login | ✅ | ❌ | Not in the HarmonyOS function list. |
| 264 | `App Shell > Logged Out Alert` Tap Continue without logging in to dismiss the alert | ✅ | ❌ | Not in the HarmonyOS function list. |
| 265 | `App Shell > Profile` Tap Close (X) to dismiss the Profile sheet | ✅ | ✅ |  |
| 266 | `App Shell > Profile` Tap Notifications to open the Notifications Center | ✅ | ✅ |  |
| 267 | `App Shell > Profile` Tap User page to open the user page | ✅ | ✅ |  |
| 268 | `App Shell > Profile` Tap Talk page to open the user talk page | ✅ | ✅ |  |
| 269 | `App Shell > Profile` Tap Watchlist to open the Watchlist | ✅ | ✅ |  |
| 270 | `App Shell > Profile` Tap Log out to open the log out confirmation | ✅ | ✅ |  |
| 271 | `App Shell > Profile` Tap Donate to start the donate flow | ✅ | ✅ | HarmonyOS opens the donation web form directly; no Apple Pay prompt. |
| 272 | `App Shell > Profile` Tap Settings to open Settings | ✅ | ✅ |  |
| 273 | `App Shell > Profile` Tap Log in / Join Wikipedia to open the Log In screen | ✅ | ✅ |  |
| 274 | `App Shell > Profile` Tap Year in Review in the profile list | ✅ | ✅ |  |
| 275 | `App Shell > Profile` Tap Settings in the profile menu to open Settings | ✅ | ✅ |  |
| 276 | `App Shell > Shared Onboarding` Tap the primary button to continue the feature onboarding | ✅ | ❌ | Not in the HarmonyOS function list. |
| 277 | `App Shell > Shared Onboarding` Tap the secondary button to run the onboarding secondary action | ✅ | ❌ | Not in the HarmonyOS function list. |
| 278 | `App Shell > Shared Survey Sheet` Select one or more reasons in the survey | ✅ | ❌ | Not in the HarmonyOS function list. |
| 279 | `App Shell > Shared Survey Sheet` Type text in the Other field to add a custom reason | ✅ | ❌ | Not in the HarmonyOS function list. |
| 280 | `App Shell > Shared Survey Sheet` Tap Submit to send the survey | ✅ | ❌ | Not in the HarmonyOS function list. |
| 281 | `App Shell > Shared Survey Sheet` Tap Cancel to dismiss the survey | ✅ | ❌ | Not in the HarmonyOS function list. |
| 282 | `App Shell > Slideshow` Tap the primary button to run the slideshow primary action | ✅ | ❌ | Not in the HarmonyOS function list. |
| 283 | `App Shell > Slideshow` Tap the secondary button to run the slideshow secondary action | ✅ | ❌ | Not in the HarmonyOS function list. |
| 284 | `App Shell > Slideshow` Tap Close to dismiss the slideshow | ✅ | ❌ | Not in the HarmonyOS function list. |
| 285 | `App Shell > Tabs` Tap Done (check mark) to close the tabs overview | ✅ | ✅ |  |
| 286 | `App Shell > Tabs` Tap More (three dots) to open the tabs overflow menu | ✅ | ✅ |  |
| 287 | `App Shell > Tabs` Tap Add tab (+) to open the Main Page in a new tab | ✅ | ✅ |  |
| 288 | `App Shell > Tabs` Tap a tab card to open its article | ✅ | ✅ |  |
| 289 | `App Shell > Tabs` Tap Close tab (X) on a tab card to close that tab | ✅ | ✅ |  |
| 290 | `App Shell > Tabs` Long press a tab card to open the tab card context menu | ✅ | ❌ | HarmonyOS has no tab card context menu. |
| 291 | `Places > Filter Menu` Tap Top read articles to filter places by top read articles | ✅ | ✅ |  |
| 292 | `Places > Filter Menu` Tap Saved articles to filter places by saved articles | ✅ | ✅ |  |
| 293 | `Places > Filter Menu` Tap Cancel to dismiss the filter menu | ✅ | ❌ | Not in the HarmonyOS function list. |
| 294 | `Places > Location Alert` Tap Enable location to start location monitoring or open the app system settings | ✅ | ✅ |  |
| 295 | `Places > Location Alert` Tap Cancel to dismiss the alert and run a default search | ✅ | ✅ |  |
| 296 | `Places > Article Callout` Tap Read on the callout to open the article | ❌ | ✅ | iOS function list has no rows for the place callout's buttons. |
| 297 | `Places > Article Callout` Tap Save/Unsave on the callout to toggle the article saved state | ❌ | ✅ | iOS function list has no rows for the place callout's buttons. |
| 298 | `Places > Article Callout` Tap Share on the callout to open the system share sheet with the article link | ❌ | ✅ | iOS function list has no rows for the place callout's buttons. |
| 299 | `Places > Search Suggestions` Tap Close (X) to close the search suggestions | ✅ | ❌ | Not in the HarmonyOS function list. |
| 300 | `Places > Search Suggestions` Tap Your current location to search near the current location | ✅ | ✅ |  |
| 301 | `Places > Search Suggestions` Tap All top articles to search top articles | ✅ | ✅ |  |
| 302 | `Places > Search Suggestions` Tap All saved articles to search saved articles | ✅ | ❌ | Not in the HarmonyOS function list. |
| 303 | `Places > Search Suggestions` Tap a recent search row to run that search | ✅ | ✅ |  |
| 304 | `Places` Tap a nearby article row to open the article | ❌ | ✅ | iOS function list has no row for tapping a Places list result. |
| 305 | `Places` Drag the panel handle vertically to resize the results panel | ❌ | ✅ | iOS function list does not itemise this Places map or list interaction. |
| 306 | `Places > Search Suggestions` Tap Clear recent searches to clear the recent places searches | ✅ | ✅ |  |
| 307 | `Search > History` Tap Clear to open the delete-all confirmation for the history | ✅ | ✅ |  |
| 308 | `Search > History` Tap a history row to open the article | ✅ | ✅ |  |
| 309 | `Search > History` Long press a history row to open the row context menu | ✅ | ❌ | HarmonyOS history rows have no long-press menu. |
| 310 | `Search > History` Swipe a history row to reveal the row actions | ✅ | ✅ |  |
| 311 | `Search > History Delete All Sheet` Tap Yes, delete all to clear the reading history | ✅ | ✅ |  |
| 312 | `Search > History Delete All Sheet` Tap Cancel to dismiss the delete-all sheet | ✅ | ✅ |  |
| 313 | `Search > History Row Actions` Tap Delete to remove the history item | ✅ | ✅ | HarmonyOS labels the action Remove. |
| 314 | `Search > History Row Actions` Tap Save for later to save the article | ✅ | ❌ | HarmonyOS history swipe offers only Remove. |
| 315 | `Search > History Row Actions` Tap Saved. Activate to unsave. to unsave the article | ✅ | ❌ | HarmonyOS history swipe offers only Remove. |
| 316 | `Search > History Row Actions` Tap Share to share the article | ✅ | ❌ | HarmonyOS history swipe offers only Remove. |
| 317 | `Search > Recent Searches` Tap Clear all to open the delete all recent searches alert | ✅ | ✅ | HarmonyOS Clear deletes all recent searches at once, without a confirmation alert. |
| 318 | `Search > Recent Searches` Tap a recent search term to run that search again | ✅ | ✅ |  |
| 319 | `Search > Recent Searches` Swipe a recent search term and tap the trash button to delete the term | ✅ | ❌ | Not in the HarmonyOS function list. |
| 320 | `Search > Recent Searches Delete Alert` Tap Delete All to remove all recent searches | ✅ | ✅ | HarmonyOS Clear deletes all recent searches at once, without a confirmation alert. |
| 321 | `Search > Recent Searches Delete Alert` Tap Cancel to dismiss the alert | ✅ | ❌ | HarmonyOS shows no confirmation alert for clearing recent searches. |
| 322 | `Search > Result Context Menu` Tap Open to open the result | ✅ | ✅ |  |
| 323 | `Search > Result Context Menu` Tap Open in new tab to open the result in a new tab | ✅ | ✅ |  |
| 324 | `Search > Result Context Menu` Tap Open in background tab to open the result in a background tab | ✅ | ✅ |  |
| 325 | `Search > Result Context Menu` Tap Save to save the result for later | ✅ | ✅ |  |
| 326 | `Search > Result Context Menu` Tap Unsave to open the unsave confirmation | ✅ | ✅ | HarmonyOS toggles the same item to Remove from saved, #325. |
| 327 | `Search > Result Context Menu` Tap View on map to show the result on the map | ✅ | ✅ |  |
| 328 | `Search > Result Context Menu` Tap Share to share the result | ✅ | ✅ |  |
| 329 | `Search > More Languages Tip` Tap the close icon on the More languages tip to dismiss the tip | ❌ | ✅ | HarmonyOS-only More languages tip on the search language bar. |
| 330 | `Search > More Languages Tip` Tap outside the More languages tip to dismiss the tip | ❌ | ✅ | HarmonyOS-only More languages tip on the search language bar. |
| 331 | `Search > Results` Tap a search result row | ✅ | ✅ |  |
| 332 | `Search > Results` Long press a search result row to open the result context menu | ✅ | ✅ |  |
| 333 | `Saved > All Articles` Tap a saved article row to open the article | ✅ | ✅ |  |
| 334 | `Saved` Tap a saved article row in edit mode to toggle its selection | ❌ | ✅ | iOS function list has no row for selecting articles in edit mode. |
| 335 | `Saved > All Articles` Long press a saved article row to open the row context menu | ✅ | ❌ | HarmonyOS saved rows have no long-press menu. |
| 336 | `Saved > All Articles` Swipe a saved article row and tap Delete to remove it from saved | ✅ | ❌ | HarmonyOS saved article rows have no swipe actions. |
| 337 | `Saved > All Articles` Swipe a saved article row and tap Share to share the article | ✅ | ❌ | HarmonyOS saved article rows have no swipe actions. |
| 338 | `Saved > All Articles` Tap the reading list tag on a saved article row to open that reading list | ✅ | ✅ |  |
| 339 | `Saved` Swipe down on the saved articles list to sync reading lists (logged-in user) | ❌ | ✅ | HarmonyOS-only pull-to-sync on the saved articles list. |
| 340 | `Saved` Swipe down on the saved articles list to open the login to sync dialog (logged-out user) | ❌ | ✅ | HarmonyOS-only login-to-sync prompt; iOS has no equivalent in its function list. |
| 341 | `Saved > All Articles` Tap the sync or download status message on a saved article row | ✅ | ❌ | Not in the HarmonyOS function list. |
| 342 | `Saved > Create Reading List` Tap Close to dismiss the Create Reading List screen | ✅ | ✅ |  |
| 343 | `Saved > Create Reading List` Type in the reading list name field to set the list name | ✅ | ✅ |  |
| 344 | `Saved > Create Reading List` Type in the description field to set an optional short description | ✅ | ✅ |  |
| 345 | `Saved > Create Reading List` Tap Return in the name field to move focus to the description field | ✅ | ✅ |  |
| 346 | `Saved > Create Reading List` Tap Return in the description field to move focus back to the name field | ✅ | ❌ | Not in the HarmonyOS function list. |
| 347 | `Saved > Create Reading List` Tap Create reading list to create the list | ✅ | ✅ |  |
| 348 | `Explore > Add To Reading List` Tap Close to close the Add To Reading List page | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 349 | `Saved > Delete All Sheet` Tap the destructive delete-all action to confirm deleting all items | ✅ | ❌ | Not in the HarmonyOS function list. |
| 350 | `Saved > Delete All Sheet` Tap Cancel to dismiss the delete-all sheet | ✅ | ❌ | Not in the HarmonyOS function list. |
| 351 | `Saved > Delete Reading List Alert` Tap Delete to delete the selected reading lists | ✅ | ✅ | HarmonyOS deletes a list from the swipe action without a confirmation alert, #372. |
| 352 | `Saved > Delete Reading List Alert` Tap Cancel to dismiss the delete reading list alert | ✅ | ❌ | HarmonyOS shows no confirmation alert when deleting a reading list. |
| 353 | `Saved > Limit Hit Panel` Tap Sort articles to open the reading list detail | ✅ | ❌ | HarmonyOS entry limit dialog offers only OK. |
| 354 | `Saved > Limit Hit Panel` Tap Cancel to dismiss the limit hit panel | ✅ | ✅ | HarmonyOS shows an entry limit dialog dismissed with OK. |
| 355 | `Saved > More Menu` Tap Sort to open the sort options | ✅ | ✅ |  |
| 356 | `Saved > More Menu` Tap Edit to toggle multi-select editing of the saved articles or reading lists | ✅ | ✅ | HarmonyOS edit mode always switches to All articles. |
| 357 | `Saved > Reading List` Type in the reading list title field to rename the list | ✅ | ❌ | Not in the HarmonyOS function list. |
| 358 | `Saved > Reading List` Type in the reading list description field to change the list description | ✅ | ❌ | Not in the HarmonyOS function list. |
| 359 | `Saved > Reading List` Tap Edit to enter editing of the reading list | ✅ | ✅ |  |
| 360 | `Saved > Reading List` Tap Done to finish editing the reading list | ✅ | ✅ | HarmonyOS labels the button Cancel. |
| 361 | `Saved > Reading List` Tap Sort to open the sort options for the list entries | ✅ | ✅ |  |
| 362 | `Saved > Reading List` Type in Search reading list to filter the entries by title | ✅ | ✅ |  |
| 363 | `Saved > Reading List` Tap a reading list article row | ✅ | ✅ |  |
| 364 | `Saved > Reading List` Tap an article row in edit mode to toggle its selection | ❌ | ✅ | iOS function list has no row for selecting articles in edit mode. |
| 365 | `Saved > Reading List` Tap a root tab bar item to switch to that tab | ❌ | ✅ | HarmonyOS repeats the root tab bar on each screen; iOS lists each tab once under App Shell. |
| 366 | `Saved > Reading List` Swipe a reading list article row and tap Share to share the article | ✅ | ❌ | HarmonyOS reading list rows have no swipe actions. |
| 367 | `Saved > Reading List` Swipe a reading list article row and tap Delete to remove the article from the list | ✅ | ❌ | HarmonyOS reading list rows have no swipe actions. |
| 368 | `Saved > Reading List` Tap Add to to open Add To Reading List for the selected articles | ✅ | ✅ |  |
| 369 | `Saved > Reading List` Tap Move to to open Add To Reading List for moving the selected articles | ✅ | ✅ |  |
| 370 | `Saved > Reading List` Tap Remove to delete the selected articles from the list without confirmation | ✅ | ✅ |  |
| 371 | `Saved > Reading Lists` Tap a reading list row to open the Reading List | ✅ | ✅ |  |
| 372 | `Saved > Reading Lists` Swipe a reading list row and tap Delete to delete the list | ✅ | ✅ |  |
| 373 | `Saved > Reading Lists` Tap Create a new list to open the Create Reading List screen | ✅ | ✅ |  |
| 374 | `Saved > Search` Type in Search saved articles to filter the current scope | ✅ | ✅ |  |
| 375 | `Saved > Search` Tap Close (X) to end the saved search | ✅ | ❌ | Not in the HarmonyOS function list. |
| 376 | `Saved > Sort Sheet` Tap Title to sort saved articles by title | ✅ | ✅ |  |
| 377 | `Saved > Sort Sheet` Tap Recently added to sort saved articles by date added | ✅ | ✅ |  |
| 378 | `Saved > Sort Sheet` Tap Cancel to dismiss the sort options | ✅ | ✅ |  |
| 379 | `Saved > Login to Sync Dialog` Tap Log in to sync your saved articles to open the login page | ❌ | ✅ | HarmonyOS-only login-to-sync prompt; iOS has no equivalent in its function list. |
| 380 | `Saved > Login to Sync Dialog` Tap Cancel to close the login to sync dialog | ❌ | ✅ | Cancel button; the iOS list does not count it as a function. |
| 381 | `Activity > Customize` Tap Switch them on to open the Customize sheet | ✅ | ✅ | HarmonyOS opens the Customize sheet from the More menu, #393. |
| 382 | `Activity > Customize` Toggle Time spent reading to show or hide that section | ✅ | ✅ |  |
| 383 | `Activity > Customize` Toggle Reading insights to show or hide that section | ✅ | ✅ |  |
| 384 | `Activity > Customize` Toggle Editing insights to show or hide that section | ✅ | ✅ |  |
| 385 | `Activity > Customize` Toggle All time impact to show or hide that section | ✅ | ❌ | HarmonyOS Customize sheet has no All time impact toggle. |
| 386 | `Activity > Customize` Toggle Last in app donation to show or hide that section | ✅ | ❌ | HarmonyOS Customize sheet has no Last in app donation toggle. |
| 387 | `Activity > Customize` Toggle Timeline of behavior to show or hide that section | ✅ | ✅ |  |
| 388 | `Activity > Customize Sheet` Toggle a switch while logged out to see the login banner and the switch return to off | ❌ | ✅ | HarmonyOS-only logged-out banner in the Activity Customize sheet. |
| 389 | `Activity > Customize Sheet` Tap Log in on the banner to open the login flow | ❌ | ✅ | HarmonyOS-only logged-out banner in the Activity Customize sheet. |
| 390 | `Activity > Editing Module` Tap the editing contributions card | ✅ | ❌ | Not in the HarmonyOS function list. |
| 391 | `Activity > Editing Module` Tap Learn about editing to start the edit introduction | ✅ | ❌ | Not in the HarmonyOS function list. |
| 392 | `Activity > Logged Out` Tap Log in / Join Wikipedia to start login or account creation | ✅ | ✅ |  |
| 393 | `Activity > More Menu` Tap Customize to open the Customize sheet | ✅ | ✅ |  |
| 394 | `Activity > More Menu` Tap Learn more | ✅ | ✅ |  |
| 395 | `Activity > More Menu` Tap Clear reading history | ✅ | ✅ |  |
| 396 | `Activity > More Menu` Tap Problem with feature to open an issue-report email | ✅ | ✅ |  |
| 397 | `Activity > Customize Sheet` Tap Cancel to dismiss the sheet without saving changes | ❌ | ✅ | Cancel button; the iOS list does not count it as a function. |
| 398 | `Activity > Onboarding` Tap Learn more about Activity to open the learn-more page | ✅ | ❌ | Not in the HarmonyOS function list. |
| 399 | `Activity > User Contributions` Tap Back to return to the previous screen | ✅ | ✅ | HarmonyOS shows contributions in the generic in-app web view. |
| 400 | `Activity > User Contributions` Tap Share to share the contributions page | ✅ | ✅ | HarmonyOS web view Share copies the link to the clipboard. |
| 401 | `Activity > User Contributions` Tap Search Wikipedia to open search | ✅ | ✅ | HarmonyOS shows contributions in the generic in-app web view. |
| 402 | `Activity > User Contributions` Tap a user tool link (talk, block log, uploads, logs, global block log, global account, filter log, global contributions) | ✅ | ❌ | Web page content links are not itemised in the HarmonyOS function list. |
| 403 | `Activity > User Contributions` Tap Search for contributions to expand the search section | ✅ | ❌ | Web page content links are not itemised in the HarmonyOS function list. |
| 404 | `Activity > User Contributions` Tap a contribution entry link (timestamp, diff, hist, page title, section) | ✅ | ❌ | Web page content links are not itemised in the HarmonyOS function list. |
| 405 | `Activity > User Contributions` Tap a user tools link (Subpages, User rights, Edit statistics, Edit summary search, Articles created, Global contributions/log/accounts) | ✅ | ❌ | Web page content links are not itemised in the HarmonyOS function list. |
| 406 | `Activity > User Contributions` Tap the footer logos to open their links | ✅ | ❌ | Web page content links are not itemised in the HarmonyOS function list. |
| 407 | `Activity > User Contributions` Tap a footer link (Privacy policy ... Desktop view) to open that page | ✅ | ❌ | Web page content links are not itemised in the HarmonyOS function list. |
| 408 | `Activity > Year in Review` Tap Close to dismiss Year in Review | ✅ | ✅ |  |
| 409 | `Activity > Year in Review` Tap More to open the Year in Review menu | ✅ | ✅ | HarmonyOS shows Learn more directly instead of a More menu, #723. |
| 410 | `Activity > Year in Review` Tap Share to share the current slide | ✅ | ✅ | HarmonyOS copies the slide text to the clipboard. |
| 411 | `Activity > Year in Review` Tap Donate (heart) to start the donate flow | ✅ | ✅ |  |
| 412 | `Activity > Year in Review` Swipe vertically to move between slides | ✅ | ✅ | HarmonyOS swipes horizontally and adds a Next button. |
| 413 | `App Shell > Profile > Year in Review` Tap Finish on the last slide to close Year in Review | ❌ | ✅ | HarmonyOS adds a Finish button on the last slide; iOS closes with the Close button. |
| 414 | `Temporary Account > End Session Alert` Tap Log out to exit the temporary session and log out | ✅ | ✅ |  |
| 415 | `Temporary Account > End Session Alert` Tap Cancel to dismiss the alert | ✅ | ✅ |  |
| 416 | `Temporary Account > Sheet` Tap Log in or create an account to open login and continue the edit on success | ✅ | ✅ |  |
| 417 | `Temporary Account > Sheet` Tap Got it to dismiss the sheet in the edit flow | ✅ | ✅ | HarmonyOS dismisses its logged-out notice with Continue without logging in, #418. |
| 418 | `Temporary Account > Sheet` Tap Continue without logging in to dismiss the sheet in the IP flow | ✅ | ✅ |  |
| 419 | `Temporary Account > Sheet` Tap Close (X) to dismiss the sheet | ✅ | ✅ | HarmonyOS Close leaves the editor rather than only the notice. |
| 420 | `Welcome > Introduction` Tap Learn more about Wikipedia to open the About Wikipedia alert | ✅ | ✅ |  |
| 421 | `Welcome > Languages` Tap Add or edit preferred languages to open the preferred languages list | ✅ | ✅ |  |
| 422 | `Welcome > Privacy` Tap Learn more about our privacy policy and terms of use to open the privacy and terms options | ✅ | ✅ |  |
| 423 | `Welcome > Privacy` Tap Get started to finish the welcome flow | ✅ | ✅ |  |
| 424 | `Global` Launch the app to be routed to the Welcome onboarding on first run and to the main app on later runs | ❌ | ✅ | Launch routing to onboarding; the iOS list does not count it as a function. |
| 425 | `App Onboarding > Feed Preference` Select the community-related content option | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 426 | `App Onboarding > Feed Preference` Select the personalized content option | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 427 | `App Onboarding > Interests` Type a term in the Interests search field to search for interests | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 428 | `App Onboarding > Interests` Tap a search result row to add it as an interest | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 429 | `App Onboarding > Interests` Tap the deselect-all button to clear the selected interests | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 430 | `App Onboarding > Intro` Tap Learn more about Wikipedia to open the external learn more page | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 431 | `App Onboarding > Languages` Tap Add or edit your languages to open language editing | ✅ | ❌ | HarmonyOS has only the Welcome flow, no feed-preference onboarding. |
| 432 | `Widgets > Continue Reading` Tap the Continue reading widget to open the most recently read article | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 433 | `Widgets > Featured Article` Tap the Featured article widget to open the featured article | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 434 | `Widgets > Lock Screen Search` Tap the lock screen Search widget to open search | ✅ | ❌ | iOS lock screen widget; the HarmonyOS port has no widgets. |
| 435 | `Widgets > On This Day` Tap the On this day widget to open On this day | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 436 | `Widgets > On This Day` Tap an article rectangle in the On this day widget to open that article | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 437 | `Widgets > Picture of the Day` Tap the Picture of the day widget to open the picture of the day | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 438 | `Widgets > Quick Actions` Tap Search Wikipedia to open search | ✅ | ❌ | iOS home-screen quick action; the HarmonyOS port defines no app shortcuts. |
| 439 | `Widgets > Quick Actions` Tap Random article to open a random article | ✅ | ❌ | iOS home-screen quick action; the HarmonyOS port defines no app shortcuts. |
| 440 | `Widgets > Quick Actions` Tap Nearby articles to open Nearby articles in Places | ✅ | ❌ | iOS home-screen quick action; the HarmonyOS port defines no app shortcuts. |
| 441 | `Widgets > Random Article` Tap the Random article widget to open a random article | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 442 | `Widgets > Search` Tap the Search widget to open search | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 443 | `Widgets > Top Read` Tap the Top read widget to open the group or first ranked article | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 444 | `Widgets > Top Read` Tap an article row in the Top read widget to open that article | ✅ | ❌ | iOS home-screen widget; the HarmonyOS port has no widgets. |
| 445 | `Explore > Article > Choose Editor Sheet` Select Visual editing to choose the visual editor mode | ✅ | ❌ | HarmonyOS has only the wikitext source editor; no editor choice sheet. |
| 446 | `Explore > Article > Choose Editor Sheet` Select Source editing to choose the source editor mode | ✅ | ❌ | HarmonyOS has only the wikitext source editor; no editor choice sheet. |
| 447 | `Explore > Article > Choose Editor Sheet` Toggle Don't show this again to keep the chosen editor as the default | ✅ | ❌ | HarmonyOS has only the wikitext source editor; no editor choice sheet. |
| 448 | `Explore > Article > Choose Editor Sheet` Tap Continue to open the chosen editor (visual mode opens in the browser) | ✅ | ❌ | HarmonyOS has only the wikitext source editor; no editor choice sheet. |
| 449 | `Explore > Article > Description Welcome` Tap Next to go to the next Description Welcome panel | ✅ | ✅ |  |
| 450 | `Explore > Article > Editing Welcome` Swipe the pager to move between the four editing welcome pages | ❌ | ✅ | HarmonyOS-only editing welcome pages; iOS has no editing welcome flow. |
| 451 | `Explore > Article > Editing Welcome` Tap Get started on the last page to dismiss the editing welcome | ❌ | ✅ | HarmonyOS-only editing welcome pages; iOS has no editing welcome flow. |
| 452 | `Explore > Article > Editing Welcome` Tap Skip to dismiss the editing welcome | ❌ | ✅ | HarmonyOS-only editing welcome pages; iOS has no editing welcome flow. |
| 453 | `Explore > Article > Editing Welcome` Tap Next to advance to the next page | ❌ | ✅ | HarmonyOS-only editing welcome pages; iOS has no editing welcome flow. |
| 454 | `Explore > Article > Description Welcome` Tap Skip to skip the Description Welcome panels | ✅ | ✅ |  |
| 455 | `Explore > Article > Description Welcome` Tap Start editing on the final panel to dismiss the welcome flow | ✅ | ✅ |  |
| 456 | `Explore > Article > Disambiguation Pages` Tap Similar pages to show similar titles | ✅ | ✅ | HarmonyOS shows the similar titles directly when the Disambiguation page opens, #182. |
| 457 | `Explore > Article > Donation Reminder Setup` Toggle Donation reminders to enable or disable the reminder | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 458 | `Explore > Article > Donation Reminder Setup` Select a Whenever I read N Articles pill to choose the reminder threshold | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 459 | `Explore > Article > Donation Reminder Setup` Select a preset amount button to choose the reminder amount | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 460 | `Explore > Article > Donation Reminder Setup` Type a custom amount in the custom amount field | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 461 | `Explore > Article > Donation Reminder Setup` Tap Confirm reminder (Update reminder) to save the reminder | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 462 | `Explore > Article > Donation Reminder Setup` Tap No thanks to save a disabled reminder and dismiss | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 463 | `Explore > Article > Donation Reminder Survey` Select an answer option (Keep it / Remove it) in the donation reminders survey | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 464 | `Explore > Article > Donation Reminder Survey` Type optional feedback in the survey text field | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 465 | `Explore > Article > Donation Reminder Survey` Tap Cancel to dismiss the donation reminders survey | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 466 | `Explore > Article > Donation Reminder Survey` Tap Submit to send the survey answer and show a thank-you toast | ✅ | ❌ | The donation reminders experiment is not in the HarmonyOS function list. |
| 467 | `Explore > Article > Edit Description` Type in the description field to enter the article description | ✅ | ✅ |  |
| 468 | `Explore > Article > Description Welcome` Swipe the pager to move between the two description welcome pages | ❌ | ✅ | iOS list has Next and Skip for description welcome, but no pager swipe. |
| 469 | `Explore > Article > Edit Description` Tap Publish description to publish the article description | ✅ | ✅ |  |
| 470 | `Explore > Article > Edit Description` Tap the license text (CC0) to open the license options | ✅ | ❌ | HarmonyOS description editor has no license options link. |
| 471 | `Explore > Article > Edit Description` Tap the Log in link to open login | ✅ | ❌ | HarmonyOS description editor has no inline Log in link. |
| 472 | `Explore > Article > Edit Description` Tap the About Wikidata button to open the About Wikidata page | ✅ | ❌ | HarmonyOS description editor has no About Wikidata button. |
| 473 | `Explore > Article > Edit Options Sheet` Tap Edit article description to open the title and description editor | ✅ | ✅ |  |
| 474 | `Explore > Article > Edit Options Sheet` Tap Edit introduction to open the lead-section editor | ✅ | ✅ |  |
| 475 | `Explore > Article > Edit Options Sheet` Tap Cancel to dismiss the edit options | ✅ | ✅ |  |
| 476 | `Explore > Article > More Menu` Tap Main page to open the Main Page article in place | ❌ | ✅ | HarmonyOS-only Main page item in the article More menu. |
| 477 | `Explore > Article > Editor` Tap Close (X) to close the editor, or to open the discard confirmation when there are unsaved changes | ✅ | ✅ | HarmonyOS closes the editor directly; no discard confirmation for unsaved changes. |
| 478 | `Explore > Article > Editor` Tap Next to open Preview or Publish Changes with the edited text | ✅ | ✅ | HarmonyOS publishes straight from the editor; no Preview or Publish Changes step. |
| 479 | `Explore > Article > Editor` Tap Undo to undo the last text change | ✅ | ❌ | HarmonyOS editor has no undo or redo controls. |
| 480 | `Explore > Article > Editor` Tap Redo to redo the last undone text change | ✅ | ❌ | HarmonyOS editor has no undo or redo controls. |
| 481 | `Explore > Article > Editor` Tap Edit notices to open the Edit Notices sheet | ✅ | ❌ | HarmonyOS editor has no edit notices. |
| 482 | `Explore > Article > Editor` Tap the Temporary Account Notice or IP Account Notice banner button to open the account notice sheet | ✅ | ✅ | HarmonyOS shows the logged-out notice automatically instead of a banner button, #416, #418. |
| 483 | `Explore > Article > Editor` Tap Reading Themes Controls (text size icon) to open the reading themes popover | ✅ | ❌ | HarmonyOS editor has no reading themes control. |
| 484 | `Explore > Article > Editor` Tap the Overflow menu (ellipsis) to open the menu with Undo, Redo and Reading themes | ✅ | ❌ | HarmonyOS editor has no overflow menu. |
| 485 | `Explore > Article > Editor` Toggle Syntax highlighting to switch wikitext syntax highlighting | ✅ | ✅ | HarmonyOS puts the syntax highlighting toggle in the article Reading Themes popup, #549. |
| 486 | `Explore > Article > Editor` Type in the wiki text editor to change the article wikitext | ✅ | ✅ |  |
| 487 | `Explore > Article > Editor` Type Command-B on a hardware keyboard to toggle bold on the selection | ✅ | ❌ | HarmonyOS editor has no hardware keyboard formatting shortcuts. |
| 488 | `Explore > Article > Editor` Type Command-I on a hardware keyboard to toggle italics on the selection | ✅ | ❌ | HarmonyOS editor has no hardware keyboard formatting shortcuts. |
| 489 | `Explore > Article > Editor` Tap an existing link in the wikitext to open Edit Link | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 490 | `Explore > Article > Editor` Toggle Bold to add or remove bold on the selected text | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 491 | `Explore > Article > Editor` Toggle Italics to add or remove italics on the selected text | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 492 | `Explore > Article > Editor` Toggle Reference to add or remove reference formatting on the selection | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 493 | `Explore > Article > Editor` Tap Link to open the link wizard for the selected text | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 494 | `Explore > Article > Editor` Toggle Template to add or remove template formatting on the selection | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 495 | `Explore > Article > Editor` Tap Open text formatting menu (plus icon) to open the Text Formatting keyboard | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 496 | `Explore > Article > Find in Page Bar` Type in the Find in page field to highlight all matches | ✅ | ✅ |  |
| 497 | `Explore > Article > Find in Page Bar` Tap Next match to move to the next match | ✅ | ✅ | HarmonyOS has no next-match button; Enter jumps to the first match. |
| 498 | `Explore > Article > Find in Page Bar` Tap Previous match to move to the previous match | ✅ | ❌ | HarmonyOS find bar has no previous-match button. |
| 499 | `Explore > Article > Find in Page Bar` Tap Clear to remove the search text and highlights | ✅ | ❌ | HarmonyOS find bar has no Clear button; Done clears the query. |
| 500 | `Explore > Article > Find in Page Bar` Tap Done to close the find-in-page bar | ✅ | ✅ |  |
| 501 | `Explore > Article > Games Announcement Sheet` Tap Play on the Which came first? announcement to start the game | ✅ | ✅ |  |
| 502 | `Explore > Article > Games Announcement Sheet` Tap No thanks on the Which came first? announcement to dismiss it | ✅ | ✅ |  |
| 503 | `Explore > Article > Video Player` Tap the close icon at the top left of the video player to close it | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 504 | `Explore > Article > Image Gallery` Tap Close (X) to dismiss the Image Gallery | ✅ | ✅ |  |
| 505 | `Explore > Article > Image Gallery` Tap Share to share the gallery image | ✅ | ✅ | HarmonyOS copies the image title and URL to the clipboard instead of a share sheet. |
| 506 | `Explore > Article > Image Gallery` Tap the image caption | ✅ | ❌ | Not in the HarmonyOS function list. |
| 507 | `Explore > Article > Image Gallery` Tap Info (circled i) in the caption panel | ✅ | ❌ | HarmonyOS gallery caption has no Info button. |
| 508 | `Explore > Article > Image Gallery` Tap the owner name in the caption panel | ✅ | ✅ | HarmonyOS opens the license page from the combined license and owner line. |
| 509 | `Explore > Image Gallery` Tap Save image to open the Save to Photos dialog | ❌ | ✅ | iOS function list has no Save image row in the gallery. |
| 510 | `Explore > Article > Keyboard Shortcut Menu` Select Share... in the keyboard menu to share the article | ✅ | ❌ | iPad hardware-keyboard menu; HarmonyOS has none. |
| 511 | `Explore > Article > Keyboard Shortcut Menu` Select Edit in the keyboard menu to edit the article | ✅ | ❌ | iPad hardware-keyboard menu; HarmonyOS has none. |
| 512 | `Explore > Article > Languages` Tap a language row to open the article in that language | ✅ | ✅ | HarmonyOS row text says it adds a preferred language; in the article it opens that language. |
| 513 | `Explore > Article > Languages` Type in Find language to filter the language list | ✅ | ✅ |  |
| 514 | `Explore > Article > Languages` Tap Edit (or Done) to toggle editing of the preferred languages list | ✅ | ✅ |  |
| 515 | `App Shell > Profile > Settings > Preferred Languages` Tap a language row to select that language | ❌ | ✅ | Not in the iOS function list. |
| 516 | `Explore > Article > Languages` Tap Add another language to open the all-languages picker | ✅ | ✅ |  |
| 517 | `Explore > Article > Languages` Tap an other-language row in edit mode to add it to the preferred languages | ✅ | ✅ |  |
| 518 | `Explore > Article > Languages` Tap Customize Explore feed to open the Explore feed settings | ✅ | ✅ |  |
| 519 | `Explore > Article > Languages` Swipe a preferred language row and tap Delete to remove the language | ✅ | ✅ |  |
| 520 | `App Shell > Profile > Settings > Preferred Languages` Drag the reorder handle of a language row to change the language order while editing | ❌ | ✅ | iOS function list has no row for reordering preferred languages. |
| 521 | `Explore > Article > Link Preview Menu` Select Open to open the previewed article | ✅ | ❌ | HarmonyOS article links have no preview menu; only Search results offer one. |
| 522 | `Explore > Article > Link Preview Menu` Select Open in new tab to open the previewed article in a new tab | ✅ | ❌ | HarmonyOS article links have no preview menu; only Search results offer one. |
| 523 | `Explore > Article > Link Preview Menu` Select Open in background tab to open the previewed article in a background tab | ✅ | ❌ | HarmonyOS article links have no preview menu; only Search results offer one. |
| 524 | `Explore > Article > Link Preview Menu` Select Save (or Remove from saved) to save or unsave the previewed article | ✅ | ❌ | HarmonyOS article links have no preview menu; only Search results offer one. |
| 525 | `Explore > Article > Link Preview Menu` Select Place to show the previewed article on the map | ✅ | ❌ | HarmonyOS article links have no preview menu; only Search results offer one. |
| 526 | `Explore > Article > Link Preview Menu` Select Share to share the previewed article | ✅ | ❌ | HarmonyOS article links have no preview menu; only Search results offer one. |
| 527 | `Explore > Article > Link Preview Popover` Tap Save in the article link popover to save the article | ✅ | ✅ |  |
| 528 | `Explore > Article > Link Preview Popover` Tap Share in the article link popover to share the article | ✅ | ✅ |  |
| 529 | `Explore > Article > Link Preview Popover` Tap Read in the article link popover to read the article | ✅ | ✅ |  |
| 530 | `Explore > Article > More Menu` Select Edit (or Edit source) to open the full-source editor | ✅ | ✅ | HarmonyOS Edit source opens the edit menu, not a full-source editor. |
| 531 | `Explore > Article > More Menu` Select Article revision history to open the page history | ✅ | ✅ |  |
| 532 | `Explore > Article > More Menu` Select Article talk page to open the talk page | ✅ | ✅ |  |
| 533 | `Explore > Article > More Menu` Select Watch to open the watchlist expiry choices | ✅ | ✅ | HarmonyOS watches permanently at once, without expiry choices. |
| 534 | `Explore > Article > More Menu` Select Unwatch to remove the article from the watchlist | ✅ | ✅ | HarmonyOS lists Watch and Unwatch in one row. |
| 535 | `Explore > Article > More Menu` Select Share to open the share sheet | ✅ | ✅ |  |
| 536 | `Explore > Article > More Menu` Select the next article tab title to open the next article in the same tab | ✅ | ❌ | Not in the HarmonyOS function list. |
| 537 | `Explore > Article > More Menu` Select the previous article tab title to open the previous article in the same tab | ✅ | ❌ | Not in the HarmonyOS function list. |
| 538 | `Explore > Article > Page History` Tap Compare to open the Diff of the two selected revisions | ✅ | ✅ | HarmonyOS Compare first enters compare mode; Compare again opens the diff, #805. |
| 539 | `Explore > Article > Page History` Tap Cancel to leave comparison mode | ✅ | ✅ |  |
| 540 | `Explore > Article > Page History` Tap a revision row to open its Diff | ✅ | ✅ |  |
| 541 | `Explore > Article > Page History` Tap a revision row in compare mode to select or deselect it | ❌ | ✅ | iOS function list has no row for selecting revisions in compare mode. |
| 542 | `Explore > Article > Page History` Scroll to the end of the revision list to load the next batch of revisions | ❌ | ✅ | Paging of the revision list; the iOS list does not count it as a function. |
| 543 | `Explore > Article > Reading Themes Popover` Drag the Text size slider to change the article text size | ✅ | ✅ |  |
| 544 | `Explore > Article > Reading Themes Popover` Drag the Brightness slider to change the screen brightness | ✅ | ✅ |  |
| 545 | `Explore > Article > Reading Themes Popover` Tap Aa (Light) to apply the light theme | ✅ | ✅ |  |
| 546 | `Explore > Article > Reading Themes Popover` Tap Aa (Sepia) to apply the sepia theme | ✅ | ✅ |  |
| 547 | `Explore > Article > Reading Themes Popover` Tap Aa (Dark) to apply the dark theme | ✅ | ✅ |  |
| 548 | `Explore > Article > Reading Themes Popover` Tap Aa (Black) to apply the black theme | ✅ | ✅ |  |
| 549 | `Explore > Article > Reading Themes Popover` Toggle Syntax Highlighting | ✅ | ✅ |  |
| 550 | `Explore > Article > Languages` Tap Close (X icon) to close the Languages page | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 551 | `Explore > Article > Reference Back-Links Sheet` Tap Close to dismiss the reference back-links sheet | ✅ | ✅ |  |
| 552 | `Explore > Article > Reference Back-Links Sheet` Tap Back to reference to scroll to and highlight the reference in the article | ✅ | ✅ | HarmonyOS jumps to the reference section rather than the citation in the text, #561. |
| 553 | `Explore > Article > Reference Back-Links Sheet` Tap Next back-link to move to the next back-link in the article | ✅ | ✅ |  |
| 554 | `Explore > Article > Reference Back-Links Sheet` Tap Previous back-link to move to the previous back-link in the article | ✅ | ✅ |  |
| 555 | `Explore > Article > Reference Popover` Tap Close to dismiss the reference popover | ✅ | ✅ | HarmonyOS shows the citation in a sheet instead of a popover, #551. |
| 556 | `Explore > Article > Reference Popover` Tap a link in the reference text to open its URL | ✅ | ❌ | Not in the HarmonyOS function list. |
| 557 | `Explore > Article > Reference Popover` Tap Next reference to show the next reference | ✅ | ✅ | HarmonyOS shows the citation in a sheet instead of a popover. |
| 558 | `Explore > Article > Reference Popover` Tap Previous reference to show the previous reference | ✅ | ✅ | HarmonyOS reaches the previous reference by swiping; no Previous button is listed, #560. |
| 559 | `Explore > Article > Reference Viewer` Tap outside the reference panel to dismiss it | ✅ | ❌ | Not in the HarmonyOS function list. |
| 560 | `Explore > Article > Reference Viewer` Swipe between references to show the adjacent reference | ✅ | ✅ |  |
| 561 | `Explore > Article > Reference Viewer` Tap Jump to reference section to go back to the reference list in the article | ✅ | ✅ |  |
| 562 | `Explore > Article > Reference Viewer` Tap Close (X) to dismiss the reference viewer | ✅ | ✅ |  |
| 563 | `Explore > Article > Share Sheet` Select Add to reading list in the share sheet to add the article to a reading list | ✅ | ✅ | HarmonyOS uses the system share panel; long-press Save opens Add to reading list instead, #170. |
| 564 | `Explore > Article > Share Sheet` Select Move to reading list in the share sheet to move the article to a reading list | ✅ | ❌ | HarmonyOS uses the system share panel, which has no Move to reading list. |
| 565 | `Explore > Article > Share Sheet` Select Share-a-fact in the share sheet to build a share card from the selected text | ✅ | ✅ | HarmonyOS lists only the Share card action; no share-sheet entry to it is listed. |
| 566 | `Explore > Article > Share Sheet` Select Open in Maps in the share sheet to open the article location in the map app | ✅ | ❌ | HarmonyOS uses the system share panel, which has no Open in Maps. |
| 567 | `Explore > Article > Share Sheet` Select Get Directions in the share sheet to get directions to the article location | ✅ | ❌ | HarmonyOS uses the system share panel, which has no Get Directions. |
| 568 | `Explore > Article > Share a Fact Building Screen` Tap Cancel to dismiss the share-a-fact building screen | ✅ | ❌ | Not in the HarmonyOS function list. |
| 569 | `Explore > Article > Table of Contents` Tap a table of contents row to scroll to that section | ✅ | ✅ |  |
| 570 | `Explore > Article > Page Issues` Tap the close icon to close the Page Issues sheet | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 571 | `Explore > Article > Table of Contents` Tap About this article in the table of contents to scroll to the article footer menu | ✅ | ❌ | Not in the HarmonyOS function list. |
| 572 | `Explore > Article > Table of Contents` Tap Read more in the table of contents to scroll to the read more section | ✅ | ❌ | Not in the HarmonyOS function list. |
| 573 | `Explore > Article > Table of Contents` Tap Close Table of contents to hide the table of contents | ✅ | ✅ |  |
| 574 | `Explore > Article > Table of Contents` Tap the dimmed strip beside the panel to close the panel | ❌ | ✅ | Tap-outside dismissal; iOS lists only Close and swipe for the table of contents. |
| 575 | `Explore > Article > Table of Contents` Swipe the table of contents to close it | ✅ | ✅ |  |
| 576 | `Explore > Article > Talk Page` Tap More Talk Page Options (ellipsis) to open the talk page options menu | ✅ | ✅ |  |
| 577 | `Explore > Article > Talk Page` Tap Add topic (+) to open New Topic | ✅ | ✅ |  |
| 578 | `Explore > Article > Talk Page` Tap Share to share the talk page | ✅ | ❌ | HarmonyOS talk page has no Share button. |
| 579 | `Explore > Article > Talk Page` Tap Find in page to search the talk page | ✅ | ❌ | HarmonyOS talk page has no find in page. |
| 580 | `Explore > Article > Talk Page` Tap the clock-with-arrow icon in the toolbar | ✅ | ❌ | Not in the HarmonyOS function list. |
| 581 | `Explore > Article > Talk Page` Tap a topic card to open the topic | ✅ | ✅ | HarmonyOS expands topics in place with the chevron; no separate topic view, #583. |
| 582 | `Explore > Article > Talk Page` Tap Subscribe or Unsubscribe (bell icon) to toggle notifications for the topic | ✅ | ❌ | HarmonyOS talk page has no topic subscriptions. |
| 583 | `Explore > Article > Talk Page` Tap Expand thread or Collapse thread (chevron) to show or hide the replies | ✅ | ✅ |  |
| 584 | `Explore > Article > Talk Page` Tap Reply on the topic to open reply compose for the topic | ✅ | ❌ | HarmonyOS talk page has no reply function. |
| 585 | `Explore > Article > Talk Page` Tap a signature link in a comment | ✅ | ❌ | Not in the HarmonyOS function list. |
| 586 | `Explore > Article > Talk Page` Tap Reply on a comment to open reply compose for that comment | ✅ | ❌ | HarmonyOS talk page has no reply function. |
| 587 | `Explore > Article > Talk Page` Tap Read more to open the coffee roll | ✅ | ✅ |  |
| 588 | `Explore > Article > Talk Page` Tap Add a new topic to open New Topic | ✅ | ✅ | HarmonyOS uses its single Add topic button, #577. |
| 589 | `Explore > Article > Talk Page` Tap Start a discussion to open New Topic | ✅ | ✅ | HarmonyOS uses its single Add topic button, #577. |
| 590 | `Explore > Article > Talk Page` Tap Retry to reload the talk page | ✅ | ❌ | Not in the HarmonyOS function list. |
| 591 | `Explore > Article > Temporary Account Sheet` Tap Log in or create an account to start login and continue the edit | ✅ | ✅ | HarmonyOS shows this as a logged-out notice inside the editor. |
| 592 | `Explore > Article > Temporary Account Sheet` Tap Got it (or Done / Continue) to dismiss the sheet and continue to the editor | ✅ | ✅ | HarmonyOS shows this as a logged-out notice inside the editor. |
| 593 | `Explore > Article > Temporary Account Sheet` Tap Learn more to open the help page | ✅ | ❌ | Not in the HarmonyOS function list. |
| 594 | `Explore > Article > Text Selection Menu` Select Edit in the text selection menu to edit the selected text | ✅ | ❌ | HarmonyOS has no Edit action in the text selection menu. |
| 595 | `Explore > Article > Text Selection Menu` Select Share... in the text selection menu to share the article with the selected text | ✅ | ❌ | HarmonyOS has no Share action in the text selection menu. |
| 596 | `Explore > Article > Watchlist Expiry Sheet` Select Permanent to watch the article permanently | ✅ | ✅ | HarmonyOS Watch always watches permanently, without an expiry sheet. |
| 597 | `Explore > Article > Watchlist Expiry Sheet` Select 1 week to watch the article for one week | ✅ | ❌ | HarmonyOS always watches permanently; there are no expiry choices. |
| 598 | `Explore > Article > Watchlist Expiry Sheet` Select 1 month to watch the article for one month | ✅ | ❌ | HarmonyOS always watches permanently; there are no expiry choices. |
| 599 | `Explore > Article > Watchlist Expiry Sheet` Select 3 months to watch the article for three months | ✅ | ❌ | HarmonyOS always watches permanently; there are no expiry choices. |
| 600 | `Explore > Article > Watchlist Expiry Sheet` Select 6 months to watch the article for six months | ✅ | ❌ | HarmonyOS always watches permanently; there are no expiry choices. |
| 601 | `Explore > Article > Watchlist Expiry Sheet` Select 1 year to watch the article for one year | ✅ | ❌ | HarmonyOS always watches permanently; there are no expiry choices. |
| 602 | `Explore > Article > Watchlist Expiry Sheet` Select Cancel to dismiss the watchlist expiry choices | ✅ | ❌ | HarmonyOS always watches permanently; there are no expiry choices. |
| 603 | `Explore > Games Splash > More Menu` Tap Learn more | ✅ | ✅ |  |
| 604 | `Explore > Games Splash > More Menu` Tap Problem with feature | ✅ | ✅ |  |
| 605 | `Explore > Games Splash > Which Came First` Tap the Close button in the game navigation bar to leave the game | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 606 | `Explore > Image Recommendations > Answer Sheet` Tap Yes to accept the image and open Media Settings | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 607 | `Explore > Image Recommendations > Answer Sheet` Tap No to open the rejection survey | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 608 | `Explore > Image Recommendations > Answer Sheet` Tap Not sure to dismiss the sheet and show the next recommendation | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 609 | `Explore > Image Recommendations > Onboarding` Tap Learn more about suggested edits on the onboarding dialog | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 610 | `Explore > Image Recommendations > Rejection Survey` Select one or more rejection reasons | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 611 | `Explore > Image Recommendations > Rejection Survey` Type other reason text | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 612 | `Explore > Image Recommendations > Rejection Survey` Tap Submit to send the rejection feedback | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 613 | `Explore > Image Recommendations > Rejection Survey` Tap Cancel to dismiss the rejection survey | ✅ | ❌ | HarmonyOS has no image recommendations (suggested edits) feature. |
| 614 | `Explore > Picture of the Day > Image Viewer` Tap Close to dismiss the image viewer | ✅ | ✅ |  |
| 615 | `Explore > Picture of the Day > Image Viewer` Tap Share on the image viewer | ✅ | ✅ | HarmonyOS copies the image title and link to the clipboard instead of a share sheet. |
| 616 | `Explore > Picture of the Day > Image Viewer` Tap the Info button on the image viewer | ✅ | ❌ | Not in the HarmonyOS function list. |
| 617 | `Explore > Which Came First > Archive` Tap an archive day to show that day's score | ✅ | ❌ | HarmonyOS has no game archive. |
| 618 | `Explore > Which Came First > Game` Tap an event card to select it as the answer | ✅ | ✅ |  |
| 619 | `Explore > Which Came First > Game` Tap Submit to submit the selected answer | ✅ | ✅ |  |
| 620 | `Explore > Which Came First > Game` Tap Next or See Results to advance after the answer is revealed | ✅ | ✅ |  |
| 621 | `Explore > Which Came First > Game` Tap Retry to reload the game after an error | ✅ | ✅ |  |
| 622 | `Explore > Which Came First > Results` Tap Share score to open the share sheet with the score image | ✅ | ❌ | HarmonyOS results view shows only the score. |
| 623 | `Explore > Which Came First > Results` Tap Play the archive to open the archive | ✅ | ❌ | HarmonyOS has no game archive. |
| 624 | `Explore > Which Came First > Results` Tap Log in to trigger the login route | ✅ | ❌ | HarmonyOS results view shows only the score. |
| 625 | `Explore > Which Came First > Results` Tap an article row from today's game to open the article | ✅ | ❌ | HarmonyOS results view shows only the score. |
| 626 | `Explore > Which Came First > Results` Open a game article in a new tab | ✅ | ❌ | HarmonyOS results view shows only the score. |
| 627 | `Explore > Which Came First > Results` Open a game article in a background tab | ✅ | ❌ | HarmonyOS results view shows only the score. |
| 628 | `Explore > Which Came First > Results` Save or unsave a game article | ✅ | ❌ | HarmonyOS results view shows only the score. |
| 629 | `Explore > Which Came First > Results` Share a game article | ✅ | ❌ | HarmonyOS results view shows only the score. |
| 630 | `Home > Community Feed > Card Menu` Tap Hide this card to hide the picture of the day card | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 631 | `Home > Community Feed > Card Menu` Tap Hide module to hide the Community module | ✅ | ❌ | HarmonyOS has no Home tab with For You and Community feeds. |
| 632 | `App Shell > Profile > Log In` Type a username in the Username field | ✅ | ✅ |  |
| 633 | `App Shell > Profile > Log In` Type a password in the Password field | ✅ | ✅ |  |
| 634 | `App Shell > Profile > Log In` Tap Log in to sign in with the entered credentials | ✅ | ✅ |  |
| 635 | `App Shell > Profile > Log In` Tap Forgot your password? to open the Forgot Password screen | ✅ | ✅ |  |
| 636 | `App Shell > Profile > Log In` Type in the CAPTCHA field to enter the captcha text | ❌ | ✅ | iOS list has a CAPTCHA field only on Create Account, not on Log In. |
| 637 | `App Shell > Profile > Log In` Tap Don't have an account? Join Wikipedia. to open the Create Account screen | ✅ | ✅ |  |
| 638 | `App Shell > Profile > Log In` Tap a link in the hCaptcha fine print | ✅ | ❌ | HarmonyOS lists hCaptcha fine-print links only on Create Account. |
| 639 | `App Shell > Profile > Log Out Alert` Tap Log out to log out of the account | ✅ | ✅ |  |
| 640 | `App Shell > Profile > Log Out Alert` Tap Cancel to dismiss the log out alert | ✅ | ✅ |  |
| 641 | `App Shell > Profile > Log In` Tap Close (X icon) to close the Log In page | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 642 | `App Shell > Profile > Notifications Center` Tap Edit to enter edit mode for multi-selecting notifications | ✅ | ✅ |  |
| 643 | `App Shell > Profile > Notifications Center` Tap Done to leave editing mode | ❌ | ✅ | iOS list counts only entering edit mode; leaving it uses the same button. |
| 644 | `App Shell > Profile > Notifications Center` Tap the Notifications Filter icon to open the Filters sheet | ✅ | ✅ | HarmonyOS filter sheet covers read status only. |
| 645 | `App Shell > Profile > Notifications Center` Tap the Projects Filter icon to open the Projects inbox view | ✅ | ✅ |  |
| 646 | `App Shell > Profile > Notifications Center` Tap a notification cell to mark it as read | ✅ | ✅ | HarmonyOS opens a notification detail page on tap. |
| 647 | `App Shell > Profile > Notifications Center` Select a notification cell in edit mode to include it in the multi-selection | ✅ | ❌ | Not in the HarmonyOS function list. |
| 648 | `App Shell > Profile > Notifications Center` Tap the notification footer link on a cell | ✅ | ❌ | Not in the HarmonyOS function list. |
| 649 | `App Shell > Profile > Notifications Center` Swipe a notification cell and tap More to open the cell options | ✅ | ❌ | Not in the HarmonyOS function list. |
| 650 | `App Shell > Profile > Notifications Center` Swipe a notification cell and tap Mark as read or Mark as unread to toggle its read state | ✅ | ❌ | Not in the HarmonyOS function list. |
| 651 | `App Shell > Profile > Notifications Center` Tap the empty-state subheader to open the Filters sheet | ✅ | ❌ | Not in the HarmonyOS function list. |
| 652 | `App Shell > Profile > Notifications Center` Tap Mark all as read to open the mark-all confirmation | ✅ | ✅ | HarmonyOS marks all as read directly, without a confirmation. |
| 653 | `App Shell > Profile > Notifications Center` Tap Mark to open the mark menu for the selected notifications | ✅ | ❌ | Not in the HarmonyOS function list. |
| 654 | `App Shell > Profile > Settings` Tap Done to close Settings | ✅ | ✅ | HarmonyOS closes Settings with a Back chevron instead of Done. |
| 655 | `App Shell > Profile > Settings` Tap Account to open the Account settings | ✅ | ✅ |  |
| 656 | `App Shell > Profile > Settings` Tap Log in to open the login | ✅ | ✅ |  |
| 657 | `App Shell > Profile > Settings` Tap Temporary Account to open the temporary account page | ✅ | ✅ |  |
| 658 | `App Shell > Profile > Settings` Tap My languages to open the preferred languages | ✅ | ✅ |  |
| 659 | `App Shell > Profile > Settings` Tap Search to open Search Settings | ✅ | ✅ |  |
| 660 | `App Shell > Profile > Settings` Tap Explore feed to open the Explore feed settings | ✅ | ✅ |  |
| 661 | `App Shell > Profile > Settings` Tap Year in Review to open the Year in Review settings | ✅ | ✅ |  |
| 662 | `App Shell > Profile > Settings` Tap Push notifications to open the push notification settings | ✅ | ✅ |  |
| 663 | `App Shell > Profile > Settings` Tap App theme to open Appearance | ✅ | ✅ |  |
| 664 | `App Shell > Profile > Settings` Tap Article storage and syncing to open Storage and Syncing | ✅ | ✅ |  |
| 665 | `App Shell > Profile > Settings` Tap Editing preferences to open the editing preferences | ✅ | ❌ | Not in the HarmonyOS function list. |
| 666 | `App Shell > Profile > Settings` Tap Database population to open Database Population | ✅ | ❌ | iOS debug-only Database Population tool; not in the HarmonyOS function list. |
| 667 | `App Shell > Profile > Settings` Tap Clear cached data to open the clear cache confirmation | ✅ | ✅ |  |
| 668 | `App Shell > Profile > Settings` Tap Rate the app to start the rate-the-app flow | ✅ | ✅ | HarmonyOS opens the AppGallery page instead of the in-app rating flow. |
| 669 | `App Shell > Profile > Settings` Tap Help and feedback to open Help | ✅ | ✅ |  |
| 670 | `App Shell > Profile > Settings` Tap About to open About | ✅ | ✅ |  |
| 671 | `App Shell > Profile > Settings` Tap a tab in the root tab bar to switch tabs | ❌ | ✅ | HarmonyOS repeats the root tab bar on each screen; iOS lists each tab once under App Shell. |
| 672 | `App Shell > Profile > User Page` Tap Search Wikipedia to open search | ✅ | ✅ | Search button of the shared in-app web view. |
| 673 | `App Shell > Profile > User Page` Tap the site banner to open its link | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 674 | `App Shell > Profile > User Page` Tap Dismiss banner (X) to hide the site banner | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 675 | `App Shell > Profile > User Page` Tap Homepage tab link to open the homepage | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 676 | `App Shell > Profile > User Page` Tap User page tab link to show the user page | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 677 | `App Shell > Profile > User Page` Tap Talk tab link to open the talk page | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 678 | `App Shell > Profile > User Page` Tap Contributions to open the user contributions | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 679 | `App Shell > Profile > User Page` Tap Watch or Unwatch (star) to toggle watching the page | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 680 | `App Shell > Profile > User Page` Tap Create (pencil) to start creating the page | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 681 | `App Shell > Profile > User Page` Tap More (three vertical dots) to open the more options | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 682 | `App Shell > Profile > User Page` Tap Create your own to start creating the user page | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 683 | `App Shell > Profile > User Page` Tap the footer logos (Wikimedia Foundation, Powered by MediaWiki) to open their links | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 684 | `App Shell > Profile > User Page` Tap a footer link (Privacy policy ... Desktop view) to open that page | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 685 | `App Shell > Profile > User Page` Tap the ? floating button to get help with editing | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS, #267. |
| 686 | `App Shell > Profile > Watchlist` Tap Filter to open the Watchlist filter screen | ✅ | ✅ |  |
| 687 | `App Shell > Profile > Watchlist` Tap a watchlist edit card to open the changed article or diff | ✅ | ✅ | HarmonyOS always opens the revision diff. |
| 688 | `App Shell > Profile > Watchlist` Tap the user chip on a card to open the user options menu | ✅ | ✅ |  |
| 689 | `App Shell > Profile > Watchlist` Tap the Modify filters link to open the filter settings | ✅ | ✅ | HarmonyOS reaches the filters through the Filter button only, #686. |
| 690 | `App Shell > Profile > Watchlist` Tap Search in the empty watchlist state to open search | ✅ | ❌ | Not in the HarmonyOS function list. |
| 691 | `App Shell > Tabs > Close All Tabs Alert` Tap Close all tabs to confirm closing all tabs | ✅ | ✅ |  |
| 692 | `App Shell > Tabs > Close All Tabs Alert` Tap Cancel to dismiss the close-all confirmation | ✅ | ✅ |  |
| 693 | `App Shell > Tabs > More Menu` Select Close all tabs to open the close-all confirmation | ✅ | ✅ |  |
| 694 | `App Shell > Tabs > Overflow Menu` Tap outside the overflow menu to dismiss it | ❌ | ✅ | Tap-outside dismissal; the iOS list does not count it for the tabs menu. |
| 695 | `App Shell > Tabs > More Menu` Select Hide article suggestions (or Show article suggestions) to toggle suggestions in the tabs overview | ✅ | ❌ | Not in the HarmonyOS function list. |
| 696 | `App Shell > Tabs > Survey` Select a satisfaction option in the tabs survey | ✅ | ❌ | Not in the HarmonyOS function list. |
| 697 | `App Shell > Tabs > Survey` Type additional thoughts in the tabs survey field | ✅ | ❌ | Not in the HarmonyOS function list. |
| 698 | `App Shell > Tabs > Survey` Tap Cancel to dismiss the tabs survey | ✅ | ❌ | Not in the HarmonyOS function list. |
| 699 | `App Shell > Tabs > Survey` Tap Submit to send the tabs survey and show a feedback toast | ✅ | ❌ | Not in the HarmonyOS function list. |
| 700 | `App Shell > Tabs > Tab Card Context Menu` Select Open tab to open the tab article | ✅ | ✅ | No tab context menu; tapping the tab card opens it, #288. |
| 701 | `App Shell > Tabs > Tab Card Context Menu` Select Share tab to share the tab | ✅ | ❌ | HarmonyOS has no tab card context menu. |
| 702 | `App Shell > Tabs > Tab Card Context Menu` Select Close tab to close the tab | ✅ | ✅ | No tab context menu; the card's Close button closes it, #289. |
| 703 | `Places > Article Location List` Tap an article location row to open that article | ❌ | ✅ | iOS function list has no row for tapping a Places list result. |
| 704 | `Search > History > History Row Context Menu` Tap Open article to open the article | ✅ | ❌ | HarmonyOS history rows have no long-press menu. |
| 705 | `Search > History > History Row Context Menu` Tap Save for later to save the article | ✅ | ❌ | HarmonyOS history rows have no long-press menu. |
| 706 | `Search > History > History Row Context Menu` Tap Unsave to remove the article from saved | ✅ | ❌ | HarmonyOS history rows have no long-press menu. |
| 707 | `Search > History > History Row Context Menu` Tap Share to share the article | ✅ | ❌ | HarmonyOS history rows have no long-press menu. |
| 708 | `Search > Result Context Menu > Unsave Confirmation` Tap Unsave to unsave the result article | ✅ | ✅ | HarmonyOS removes from saved directly, without a confirmation, #325. |
| 709 | `Search > Result Context Menu > Unsave Confirmation` Tap Cancel to dismiss the unsave confirmation | ✅ | ❌ | HarmonyOS shows no unsave confirmation. |
| 710 | `Saved > All Articles > Download Failed Sheet` Tap Retry to download the article again | ✅ | ❌ | Not in the HarmonyOS function list. |
| 711 | `Saved > All Articles > Download Failed Sheet` Tap Cancel to dismiss the download failed sheet | ✅ | ❌ | Not in the HarmonyOS function list. |
| 712 | `Saved > All Articles > Saved Row Context Menu` Tap Open to open the saved article | ✅ | ❌ | HarmonyOS saved rows have no long-press menu. |
| 713 | `Saved > All Articles > Saved Row Context Menu` Tap Open in new tab to open the saved article in a new tab | ✅ | ❌ | HarmonyOS saved rows have no long-press menu. |
| 714 | `Saved > All Articles > Saved Row Context Menu` Tap Open in background tab to open the saved article in a background tab | ✅ | ❌ | HarmonyOS saved rows have no long-press menu. |
| 715 | `Saved > All Articles > Saved Row Context Menu` Tap Remove from saved to unsave the article | ✅ | ❌ | HarmonyOS saved rows have no long-press menu. |
| 716 | `Saved > All Articles > Saved Row Context Menu` Tap Share to share the saved article | ✅ | ❌ | HarmonyOS saved rows have no long-press menu. |
| 717 | `Saved > All Articles > Unsave Alert` Tap Unsave to remove the article from all reading lists | ✅ | ✅ | HarmonyOS unsaves selected articles directly, without an alert, #104. |
| 718 | `Saved > All Articles > Unsave Alert` Tap Cancel to dismiss the unsave alert | ✅ | ❌ | HarmonyOS shows no unsave alert. |
| 719 | `Saved > Reading List > Sort Sheet` Tap Title to sort the list entries by title | ✅ | ✅ |  |
| 720 | `Saved > Reading List > Sort Sheet` Tap Recently added to sort the list entries by date added | ✅ | ✅ |  |
| 721 | `Saved > Reading List > Survey Alert` Tap Take survey to open the survey URL | ✅ | ❌ | Not in the HarmonyOS function list. |
| 722 | `Saved > Reading List > Survey Alert` Tap Not now to dismiss the survey alert | ✅ | ❌ | Not in the HarmonyOS function list. |
| 723 | `Activity > Year in Review > More Menu` Tap Learn more to open Year in Review information | ✅ | ✅ | HarmonyOS shows Learn more directly on the screen, not in a More menu. |
| 724 | `Activity > Year in Review > More Menu` Tap Share feedback to compose a pre-filled Year in Review feedback email | ✅ | ❌ | Not in the HarmonyOS function list. |
| 725 | `Welcome > Introduction > About Wikipedia Alert` Tap Got it to dismiss the About Wikipedia alert | ✅ | ✅ |  |
| 726 | `Welcome > Privacy > Privacy and Terms Sheet` Tap Privacy policy to open the privacy policy | ✅ | ✅ |  |
| 727 | `Welcome > Privacy > Privacy and Terms Sheet` Tap the terms action to open the terms of use | ✅ | ✅ |  |
| 728 | `Welcome > Privacy Options Menu` Tap Cancel to dismiss the privacy options menu without opening a page | ❌ | ✅ | Cancel button; the iOS list does not count it as a function. |
| 729 | `Explore > Article > Edit Description > Description Help` Tap About Wikidata to open the About Wikidata page | ✅ | ❌ | HarmonyOS description editor has no Description Help screen. |
| 730 | `Explore > Article > Edit Description > Description Help` Tap Wikidata guide for writing descriptions to open the guide page | ✅ | ❌ | HarmonyOS description editor has no Description Help screen. |
| 731 | `Explore > Article > Edit Description > License Alert` Tap Terms of Use in the license alert | ✅ | ❌ | HarmonyOS description editor has no license alert. |
| 732 | `Explore > Article > Edit Description > License Alert` Tap CC0 in the license alert | ✅ | ❌ | HarmonyOS description editor has no license alert. |
| 733 | `Explore > Article > Edit Description > License Alert` Tap Cancel to dismiss the license alert | ✅ | ❌ | HarmonyOS description editor has no license alert. |
| 734 | `Explore > Article > Edit Description > Publish Success Alert` Tap Done to dismiss the Description published alert | ✅ | ❌ | HarmonyOS shows no Description published alert. |
| 735 | `Explore > Article > Editor > Blocked Panel` Tap the link in the blocked user panel to leave the blocked edit attempt | ✅ | ❌ | HarmonyOS editor has no blocked user panel. |
| 736 | `Explore > Article > Editor > Discard Edit Sheet` Tap Discard Edit to discard the unsaved changes and close the editor | ✅ | ❌ | HarmonyOS closes the editor without a discard confirmation sheet. |
| 737 | `Explore > Article > Editor > Discard Edit Sheet` Tap Keep Editing to dismiss the sheet and stay in the editor | ✅ | ❌ | HarmonyOS closes the editor without a discard confirmation sheet. |
| 738 | `Explore > Article > Editor > Edit Link` Type in Display text to change the link label | ✅ | ❌ | HarmonyOS editor has no Edit Link wizard. |
| 739 | `Explore > Article > Editor > Edit Link` Tap Link target to search articles for a new link target | ✅ | ❌ | HarmonyOS editor has no Edit Link wizard. |
| 740 | `Explore > Article > Editor > Edit Link` Tap Remove link to remove the link wikitext | ✅ | ❌ | HarmonyOS editor has no Edit Link wizard. |
| 741 | `Explore > Article > Editor > Edit Link` Tap the close control to dismiss Edit Link | ✅ | ❌ | HarmonyOS editor has no Edit Link wizard. |
| 742 | `Explore > Article > Editor > Edit Link` Tap the finish control to replace the link target and label | ✅ | ❌ | HarmonyOS editor has no Edit Link wizard. |
| 743 | `Explore > Article > Editor > Edit Notices Sheet` Toggle Always display edit notices to save the display preference | ✅ | ❌ | HarmonyOS editor has no edit notices. |
| 744 | `Explore > Article > Editor > Edit Notices Sheet` Tap Done to dismiss the Edit Notices sheet | ✅ | ❌ | HarmonyOS editor has no edit notices. |
| 745 | `Explore > Article > Editor > Edit Notices Sheet` Tap a link in an edit notice to leave the editor and open the linked page | ✅ | ❌ | HarmonyOS editor has no edit notices. |
| 746 | `Explore > Article > Editor > Editor Overflow Menu` Tap Undo in the overflow menu to undo the last text change | ✅ | ❌ | HarmonyOS editor has no overflow menu. |
| 747 | `Explore > Article > Editor > Editor Overflow Menu` Tap Redo in the overflow menu to redo the last undone text change | ✅ | ❌ | HarmonyOS editor has no overflow menu. |
| 748 | `Explore > Article > Editor > Editor Overflow Menu` Tap Reading themes in the overflow menu to open the reading themes popover | ✅ | ❌ | HarmonyOS editor has no overflow menu. |
| 749 | `Explore > Article > Editor > Find and Replace Bar` Tap Close on the Find and replace header to close find and restore the navigation bar | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 750 | `Explore > Article > Editor > Find and Replace Bar` Type in the Find field to search the wikitext | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 751 | `Explore > Article > Editor > Find and Replace Bar` Tap Clear find to empty the Find field | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 752 | `Explore > Article > Editor > Find and Replace Bar` Tap Previous find result to move to the previous match | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 753 | `Explore > Article > Editor > Find and Replace Bar` Tap Next find result to move to the next match | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 754 | `Explore > Article > Editor > Find and Replace Bar` Type in the Replace with... field to set the replacement text | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 755 | `Explore > Article > Editor > Find and Replace Bar` Tap Clear replace to empty the replacement field | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 756 | `Explore > Article > Editor > Find and Replace Bar` Tap Switch replace type (ellipsis) to open the Find and replace menu | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 757 | `Explore > Article > Editor > Find and Replace Bar` Tap Replace to replace the match (or all matches, per the selected replace type) | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 758 | `Explore > Article > Editor > Formatting Toolbar` Tap Open text formatting menu to open the Text Formatting keyboard | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 759 | `Explore > Article > Editor > Formatting Toolbar` Toggle Reference to add or remove reference formatting | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 760 | `Explore > Article > Editor > Formatting Toolbar` Tap Link to open Edit Link for an existing link or Insert Link otherwise | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 761 | `Explore > Article > Editor > Formatting Toolbar` Toggle Template to add or remove template formatting | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 762 | `Explore > Article > Editor > Formatting Toolbar` Tap Image to open Insert Media | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 763 | `Explore > Article > Editor > Formatting Toolbar` Tap Find in page to switch the toolbar to the Find and replace bar | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 764 | `Explore > Article > Editor > Formatting Toolbar` Toggle Unordered list to apply or remove a bullet list | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 765 | `Explore > Article > Editor > Formatting Toolbar` Toggle Ordered list to apply or remove a numbered list | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 766 | `Explore > Article > Editor > Formatting Toolbar` Tap Decrease indent to decrease the list indentation | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 767 | `Explore > Article > Editor > Formatting Toolbar` Tap Increase indent to increase the list indentation | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 768 | `Explore > Article > Editor > Formatting Toolbar` Tap Move cursor up to move the caret to the previous line | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 769 | `Explore > Article > Editor > Formatting Toolbar` Tap Move cursor down to move the caret to the next line | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 770 | `Explore > Article > Editor > Formatting Toolbar` Tap Move cursor left to move the caret to the previous character | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 771 | `Explore > Article > Editor > Formatting Toolbar` Tap Move cursor right to move the caret to the next character | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 772 | `Explore > Article > Editor > Formatting Toolbar` Tap Show more formatting options to switch between the primary and secondary toolbar pages | ✅ | ❌ | HarmonyOS editor is a plain text field with no formatting toolbar. |
| 773 | `Explore > Article > Editor > Insert Link` Type in the search field to search for a page to link | ✅ | ❌ | HarmonyOS editor has no Insert Link search. |
| 774 | `Explore > Article > Editor > Insert Link` Tap a search result to insert a link to that page into the wikitext | ✅ | ❌ | HarmonyOS editor has no Insert Link search. |
| 775 | `Explore > Article > Editor > Insert Link` Tap the close control to dismiss Insert Link | ✅ | ❌ | HarmonyOS editor has no Insert Link search. |
| 776 | `Explore > Article > Editor > Insert Media` Type in the search field to search Wikimedia Commons files | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 777 | `Explore > Article > Editor > Insert Media` Tap Next to open Media Settings for the selected image | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 778 | `Explore > Article > Editor > Insert Media` Tap the close control to dismiss Insert Media | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 779 | `Explore > Article > Editor > Insert Media` Long press an image result to open the result preview menu | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 780 | `Explore > Article > Editor > Leave Editing Alert` Tap Discard edits to dismiss the editor and open Notifications Center | ✅ | ❌ | HarmonyOS editor has no Leave Editing alert. |
| 781 | `Explore > Article > Editor > Leave Editing Alert` Tap Cancel to dismiss the alert and stay in the editor | ✅ | ❌ | HarmonyOS editor has no Leave Editing alert. |
| 782 | `Explore > Article > Editor > Preview` Tap Next to open Publish Changes | ✅ | ❌ | HarmonyOS has no edit Preview screen; it publishes from the editor. |
| 783 | `Explore > Article > Editor > Preview` Tap Next (image recommendations flow) to open Publish Changes with the image summary and edit tags preset | ✅ | ❌ | HarmonyOS has no edit Preview screen; it publishes from the editor. |
| 784 | `Explore > Article > Editor > Preview` Tap a link in the preview to show the link popup or the internal link preview | ✅ | ❌ | HarmonyOS has no edit Preview screen; it publishes from the editor. |
| 785 | `Explore > Article > Editor > Preview` Tap Learn more to open the image recommendations help page in-app | ✅ | ❌ | HarmonyOS has no edit Preview screen; it publishes from the editor. |
| 786 | `Explore > Article > Editor > Preview` Tap Report issue to open an email to ios-support@wikimedia.org | ✅ | ❌ | HarmonyOS has no edit Preview screen; it publishes from the editor. |
| 787 | `Explore > Article > Editor > Protected Page Panel` Tap the link in the protected page warning panel to leave the edit attempt | ✅ | ❌ | HarmonyOS editor has no protected page warning panel. |
| 788 | `Explore > Article > Editor > Selection Not Found Alert` Tap OK to dismiss the alert and open the editor without a selection | ✅ | ❌ | HarmonyOS editor has no Selection Not Found alert. |
| 789 | `Explore > Article > Editor > Text Formatting Keyboard` Tap Close text formatting menu to hide the Text Formatting keyboard | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 790 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Bold to add or remove bold on the selection | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 791 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Italics to add or remove italics on the selection | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 792 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Underline to add or remove underline on the selection | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 793 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Strikethrough to add or remove strikethrough on the selection | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 794 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Reference to add or remove reference formatting | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 795 | `Explore > Article > Editor > Text Formatting Keyboard` Tap Link to open the link wizard | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 796 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Unordered list to apply or remove a bullet list | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 797 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Ordered list to apply or remove a numbered list | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 798 | `Explore > Article > Editor > Text Formatting Keyboard` Tap Decrease indent to decrease the list indentation | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 799 | `Explore > Article > Editor > Text Formatting Keyboard` Tap Increase indent to increase the list indentation | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 800 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Superscript to add or remove superscript on the selection | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 801 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Subscript to add or remove subscript on the selection | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 802 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Template to add or remove template formatting | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 803 | `Explore > Article > Editor > Text Formatting Keyboard` Toggle Comment to add or remove comment formatting | ✅ | ❌ | HarmonyOS editor has no Text Formatting keyboard. |
| 804 | `Explore > Article > Editor > Unexpected Error Alert` Tap OK to dismiss the Unexpected error alert | ✅ | ❌ | HarmonyOS shows editor errors as inline text; no alert to dismiss. |
| 805 | `Explore > Article > Page History > Comparison Selection Bar` Tap Compare on the bottom bar to compare the two selected revisions | ✅ | ✅ |  |
| 806 | `Explore > Article > Page History > Comparison Selection Bar` Tap the first selection button to reset the first selected revision | ✅ | ✅ |  |
| 807 | `Explore > Article > Page History > Comparison Selection Bar` Tap the second selection button to reset the second selected revision | ✅ | ✅ |  |
| 808 | `Explore > Article > Page History > Diff` Tap Show or Hide to expand or collapse unchanged context lines | ✅ | ✅ |  |
| 809 | `Explore > Article > Page History > Diff` Tap the article title in the header to open the article | ✅ | ✅ |  |
| 810 | `Explore > Article > Page History > Diff` Tap the username in the header to open the user's contributions, talk or user page | ✅ | ✅ | HarmonyOS opens a user menu offering contributions, talk page or user page. |
| 811 | `Explore > Article > Page History > Diff` Tap Previous Revision to show the diff of the previous revision | ✅ | ❌ | HarmonyOS diff has no previous or next revision navigation. |
| 812 | `Explore > Article > Page History > Diff` Tap Next Revision to show the diff of the next revision | ✅ | ❌ | HarmonyOS diff has no previous or next revision navigation. |
| 813 | `Explore > Article > Page History > Diff` Tap Thank User to send Thanks for the revision | ✅ | ❌ | HarmonyOS diff has no Thank button; thanks are sent from the Watchlist user menu. |
| 814 | `Explore > Article > Page History > Diff` Tap Undo to open the Undo alert | ✅ | ❌ | HarmonyOS diff has no Undo. |
| 815 | `Explore > Article > Page History > Diff` Tap More to open the diff options menu | ✅ | ❌ | HarmonyOS diff has no More menu. |
| 816 | `Explore > Article > Talk Page > Alert` Tap OK to dismiss the publish failure alert | ✅ | ❌ | Not in the HarmonyOS function list. |
| 817 | `Explore > Article > Talk Page > New Topic` Type in the Topic title field | ✅ | ✅ |  |
| 818 | `Explore > Article > Talk Page > New Topic` Type in the Description field | ✅ | ✅ |  |
| 819 | `Explore > Article > Talk Page > New Topic` Tap Publish to publish the new topic | ✅ | ✅ |  |
| 820 | `Explore > Article > Talk Page > New Topic` Tap Temporary account to see the temporary-account notice | ❌ | ✅ | HarmonyOS-only temporary-account notice on New Topic. |
| 821 | `Explore > Article > Talk Page > New Topic` Tap the close control to close New Topic | ✅ | ✅ | HarmonyOS splits close into empty and with-text cases. |
| 822 | `Explore > Article > Talk Page > New Topic` Tap the Terms of Use link in the publishing notice | ✅ | ❌ | HarmonyOS New Topic has no Terms of Use link. |
| 823 | `Explore > Article > Talk Page > New Topic` Tap Bold in the formatting toolbar to apply bold | ✅ | ✅ | HarmonyOS appends bold markup to the end of the description. |
| 824 | `Explore > Article > Talk Page > New Topic` Tap Italics in the formatting toolbar to apply italics | ✅ | ✅ | HarmonyOS appends italic markup to the end of the description. |
| 825 | `Explore > Article > Talk Page > New Topic` Tap Insert link in the formatting toolbar to open Insert Link | ✅ | ✅ | HarmonyOS appends link markup instead of opening Insert Link. |
| 826 | `App Shell > Profile > Log In > Create Account` Tap Cancel (X icon) to close the Create Account page | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 827 | `Explore > Article > Talk Page > Not Logged In Panel` Tap Log in or create account to open login | ✅ | ❌ | HarmonyOS talk page has no Not Logged In panel. |
| 828 | `Explore > Article > Talk Page > Not Logged In Panel` Tap Edit without logging in to continue publishing | ✅ | ❌ | HarmonyOS talk page has no Not Logged In panel. |
| 829 | `Explore > Article > Talk Page > Onboarding` Tap the button on the Talk pages onboarding dialog to return to reply | ✅ | ❌ | HarmonyOS has no talk pages onboarding dialog. |
| 830 | `Explore > Article > Talk Page > Overflow Menu` Tap Open all threads to expand all topics | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 831 | `Explore > Article > Talk Page > Overflow Menu` Tap Revision history to open Page History | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 832 | `Explore > Article > Talk Page > Overflow Menu` Tap Edit source to open the editor | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 833 | `Explore > Article > Talk Page > Overflow Menu` Tap Read in web to open the talk page in the web view | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 834 | `Explore > Article > Talk Page > Overflow Menu` Tap Contributions to open the user's contributions | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 835 | `Explore > Article > Talk Page > Overflow Menu` Tap User groups to open the user's groups page | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 836 | `Explore > Article > Talk Page > Overflow Menu` Tap Logs to open the logs page | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 837 | `Explore > Article > Talk Page > Overflow Menu` Tap Archives to open Talk Page Archives | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 838 | `Explore > Article > Talk Page > Overflow Menu` Tap Page information to open the page information | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 839 | `Explore > Article > Talk Page > Overflow Menu` Tap Permanent link to open the permanent link to the page | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 840 | `Explore > Article > Talk Page > Overflow Menu` Tap Change language to open the language list | ✅ | ✅ |  |
| 841 | `Explore > Article > Talk Page > Coffee Roll Sheet` Tap the sheet Close button to dismiss the lead section sheet | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 842 | `Explore > Article > Talk Page > Overflow Menu` Tap What links here to open the what-links-here page | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 843 | `Explore > Article > Talk Page > Overflow Menu` Tap About talk pages to open the talk pages help | ✅ | ❌ | HarmonyOS talk page overflow menu offers only Change language. |
| 844 | `Explore > Article > Talk Page > Reply Compose` Type in the Reply to text field to write the reply | ✅ | ❌ | HarmonyOS talk page has no reply function. |
| 845 | `Explore > Article > Talk Page > Reply Compose` Tap Publish reply to publish the reply | ✅ | ❌ | HarmonyOS talk page has no reply function. |
| 846 | `Explore > Article > Talk Page > Reply Compose` Tap Close reply view to close reply compose | ✅ | ❌ | HarmonyOS talk page has no reply function. |
| 847 | `Explore > Article > Talk Page > Talk Page Archives` Tap an archive row to open that archive page | ✅ | ❌ | HarmonyOS has no Talk Page Archives screen. |
| 848 | `Explore > Article > Web View > JavaScript Confirm Alert` Tap OK to accept the web page confirm dialog | ✅ | ❌ | Not in the HarmonyOS function list. |
| 849 | `Explore > Article > Web View > JavaScript Confirm Alert` Tap Cancel to reject the web page confirm dialog | ✅ | ❌ | Not in the HarmonyOS function list. |
| 850 | `App Shell > Profile > Donate > Native Form` Tap an amount preset button to select the donation amount | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 851 | `App Shell > Profile > Donate > Native Form` Type a custom amount in the custom amount field | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 852 | `App Shell > Profile > Donate > Native Form` Tap the transaction fee checkbox to add the fee to the donation | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 853 | `App Shell > Profile > Donate > Native Form` Tap the monthly recurring donation checkbox to make the donation monthly | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 854 | `App Shell > Profile > Donate > Native Form` Tap the email opt-in checkbox to allow occasional emails | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 855 | `App Shell > Profile > Donate > Native Form` Tap the Apple Pay donate button to validate the amount and present the Apple Pay sheet | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 856 | `App Shell > Profile > Donate > Native Form` Tap Problems donating? to open its help page | ✅ | ❌ | Native Apple Pay form link; HarmonyOS uses the donation web page. |
| 857 | `App Shell > Profile > Donate > Native Form` Tap Other ways to give to open its help page | ✅ | ❌ | Native Apple Pay form link; HarmonyOS uses the donation web page. |
| 858 | `App Shell > Profile > Donate > Native Form` Tap Frequently asked questions to open its help page | ✅ | ❌ | Native Apple Pay form link; HarmonyOS uses the donation web page. |
| 859 | `App Shell > Profile > Donate > Native Form` Tap Tax deductibility information to open its help page | ✅ | ❌ | Native Apple Pay form link; HarmonyOS uses the donation web page. |
| 860 | `App Shell > Profile > Donate > Payment Method Prompt` Tap Donate with Apple Pay to open the native donation form | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 861 | `App Shell > Profile > Donate > Payment Method Prompt` Tap Donate a different amount with Apple Pay to open the native form | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 862 | `App Shell > Profile > Donate > Payment Method Prompt` Tap Donate (pledge amount) with Apple Pay to open the native form with the pledge preselected | ✅ | ❌ | HarmonyOS opens the donation web page; no Apple Pay. |
| 863 | `App Shell > Profile > Donate > Payment Method Prompt` Tap Other payment method to open the donate web form | ✅ | ✅ | HarmonyOS skips the prompt and opens the donation web form directly. |
| 864 | `App Shell > Profile > Donate > Payment Method Prompt` Tap Cancel to dismiss the payment method prompt | ✅ | ❌ | HarmonyOS has no payment method prompt. |
| 865 | `App Shell > Profile > Donate > Web Form` Tap the Wikipedia sandbox link | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS. |
| 866 | `App Shell > Profile > Donate > Web Form` Tap the creating an account link | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS. |
| 867 | `App Shell > Profile > Donate > Web Form` Tap the introduction link | ✅ | ✅ | Part of the web page content; not listed separately in HarmonyOS. |
| 868 | `App Shell > Profile > Donate > Web Form` Tap Search in the navigation bar to open search | ✅ | ✅ | Search button of the shared in-app web view. |
| 869 | `App Shell > Profile > Settings > Help` Tap a link in the FAQ web content to navigate within the page | ❌ | ✅ | Web page content; the iOS list does not itemise Help FAQ links. |
| 870 | `Explore > Web View` Tap Retry on the load error to reload the page | ❌ | ✅ | Web view load error retry; not in the iOS function list. |
| 871 | `App Shell > Profile > Donate > Web Form` Tap Action (share) to open the share sheet | ✅ | ✅ | HarmonyOS copies the page link to the clipboard instead of a share sheet. |
| 872 | `App Shell > Profile > Donate > Web Form` Tap Close to dismiss the web form | ✅ | ✅ | HarmonyOS leaves the web view with Back. |
| 873 | `App Shell > Profile > Donate > Web Form` Tap the Donate overlay button to log a donate action | ✅ | ❌ | Not in the HarmonyOS function list. |
| 874 | `App Shell > Profile > Donate > Web Form` Tap Return to article or Return to leave the thank-you page | ✅ | ❌ | Not in the HarmonyOS function list. |
| 875 | `App Shell > Profile > Log In > Change Password` Type a new password in the New password field | ✅ | ✅ |  |
| 876 | `App Shell > Profile > Log In > Change Password` Type the new password again in the Confirm new password field | ✅ | ✅ |  |
| 877 | `App Shell > Profile > Log In > Change Password` Tap Save to set the new password and finish logging in | ✅ | ✅ |  |
| 878 | `App Shell > Profile > Log In > Create Account` Type a username in the Username field | ✅ | ✅ |  |
| 879 | `App Shell > Profile > Log In > Create Account` Type a password in the Password field | ✅ | ✅ |  |
| 880 | `App Shell > Profile > Log In > Create Account` Type the password again in the Confirm password field | ✅ | ✅ |  |
| 881 | `App Shell > Profile > Log In > Create Account` Type an optional email in the Email field | ✅ | ✅ |  |
| 882 | `App Shell > Profile > Log In > Create Account` Tap Create your account to submit the registration | ✅ | ✅ |  |
| 883 | `App Shell > Profile > Log In > Create Account` Tap Already have an account? Log in. to return to log in | ✅ | ✅ |  |
| 884 | `App Shell > Profile > Log In > Create Account` Tap a link in the hCaptcha fine print | ✅ | ✅ | HarmonyOS lists each fine-print link separately. |
| 885 | `App Shell > Profile > Log In > Create Account` Type the CAPTCHA text in the CAPTCHA text field | ✅ | ✅ |  |
| 886 | `App Shell > Profile > Log In > Create Account` Tap Can't see the image? Request account. to open the Request an account page | ✅ | ❌ | Not in the HarmonyOS function list. |
| 887 | `App Shell > Profile > Log In > Create Account` Tap the Refresh CAPTCHA icon to load a new CAPTCHA image | ✅ | ❌ | HarmonyOS refreshes the CAPTCHA automatically; no refresh button listed. |
| 888 | `App Shell > Profile > Log In > Create Account` Tap the CAPTCHA info icon to open the CAPTCHA help page | ✅ | ❌ | Not in the HarmonyOS function list. |
| 889 | `App Shell > Profile > Log In > Forgot Password` Type a username in the Username field | ✅ | ✅ |  |
| 890 | `App Shell > Profile > Log In > Forgot Password` Type an email in the Email field | ✅ | ✅ |  |
| 891 | `App Shell > Profile > Log In > Forgot Password` Tap Reset to send password reset instructions by email | ✅ | ✅ |  |
| 892 | `App Shell > Profile > Log In > Change Password` Tap Cancel (X icon) to close the Change Password page | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 893 | `App Shell > Profile > Log In > Logged-Out Panel` Tap Log back in to your account to open the login screen | ✅ | ❌ | Not in the HarmonyOS function list. |
| 894 | `App Shell > Profile > Log In > Logged-Out Panel` Tap Continue without logging in to dismiss the logged-out panel | ✅ | ❌ | Not in the HarmonyOS function list. |
| 895 | `App Shell > Profile > Log In > Two-Factor Login` Type the verification code into the token boxes | ✅ | ✅ |  |
| 896 | `App Shell > Profile > Log In > Two-Factor Login` Type a backup code in the backup code field | ✅ | ✅ |  |
| 897 | `App Shell > Profile > Log In > Two-Factor Login` Tap Sign in using backup code to switch between backup code and regular code entry | ✅ | ✅ |  |
| 898 | `App Shell > Profile > Log In > Two-Factor Login` Tap Continue log in to submit the verification code | ✅ | ✅ |  |
| 899 | `App Shell > Profile > Log In > Forgot Password` Tap Cancel (X icon) to close the Forgot Password page | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 900 | `App Shell > Profile > Notifications Center > Cell More Sheet` Tap Mark as Read or Mark as Unread to toggle the cell read state | ✅ | ❌ | Not in the HarmonyOS function list. |
| 901 | `App Shell > Profile > Notifications Center > Cell More Sheet` Tap Notification settings to open notification settings | ✅ | ❌ | Not in the HarmonyOS function list. |
| 902 | `App Shell > Profile > Notifications Center > Cell More Sheet` Tap a destination link to navigate to that link target | ✅ | ✅ | HarmonyOS shows destination links on a notification detail page. |
| 903 | `App Shell > Profile > Notifications Center > Cell More Sheet` Tap Cancel to dismiss the sheet | ✅ | ❌ | Not in the HarmonyOS function list. |
| 904 | `App Shell > Profile > Notifications Center > Filters` Select All in Read Status to show all notifications | ✅ | ✅ |  |
| 905 | `App Shell > Profile > Notifications Center > Read Status Filter Sheet` Tap read to show only read notifications | ❌ | ✅ | iOS function list lists only the All and Unread read-status filters. |
| 906 | `App Shell > Profile > Notifications Center > Filters` Select Unread in Read Status to show only unread notifications | ✅ | ✅ |  |
| 907 | `App Shell > Profile > Notifications Center > Projects Sheet` Tap a project row to include or exclude that project in the filter | ❌ | ✅ | iOS function list has no row for toggling projects in the Projects view. |
| 908 | `App Shell > Profile > Notifications Center > Filters` Toggle All types to switch every notification type on or off | ✅ | ❌ | HarmonyOS filters notifications only by read status and project. |
| 909 | `App Shell > Profile > Notifications Center > Filters` Toggle a notification type switch to filter that type in or out of the inbox | ✅ | ❌ | HarmonyOS filters notifications only by read status and project. |
| 910 | `App Shell > Profile > Notifications Center > Mark Action Sheet` Tap Mark as Read in the action sheet to mark the selected notifications as read | ✅ | ❌ | Not in the HarmonyOS function list. |
| 911 | `App Shell > Profile > Notifications Center > Mark Action Sheet` Tap Mark as Unread in the action sheet to mark the selected notifications as unread | ✅ | ❌ | Not in the HarmonyOS function list. |
| 912 | `App Shell > Profile > Notifications Center > Mark Action Sheet` Tap Cancel to dismiss the action sheet | ✅ | ❌ | Not in the HarmonyOS function list. |
| 913 | `App Shell > Profile > Notifications Center > Mark All As Read Confirmation` Tap Mark as Read to mark all notifications as read and exit edit mode | ✅ | ✅ | HarmonyOS marks all as read directly, without a confirmation. |
| 914 | `App Shell > Profile > Notifications Center > Mark All As Read Confirmation` Tap Cancel to dismiss the confirmation without changes | ✅ | ❌ | HarmonyOS has no mark-all confirmation. |
| 915 | `App Shell > Profile > Notifications Center > Mark Menu` Tap Mark as Read to mark the selected notifications as read | ✅ | ❌ | Not in the HarmonyOS function list. |
| 916 | `App Shell > Profile > Notifications Center > Mark Menu` Tap Mark as Unread to mark the selected notifications as unread | ✅ | ❌ | Not in the HarmonyOS function list. |
| 917 | `App Shell > Profile > Notifications Center > Onboarding Modal` Tap Continue to dismiss the Editing notifications modal | ✅ | ❌ | Not in the HarmonyOS function list. |
| 918 | `App Shell > Profile > Notifications Center > Onboarding Modal` Tap Learn more about notifications to open the notifications help | ✅ | ❌ | Not in the HarmonyOS function list. |
| 919 | `App Shell > Profile > Notifications Center > Push Opt-In Alert` Tap Turn on push notifications to start push opt-in | ✅ | ❌ | Not in the HarmonyOS function list. |
| 920 | `App Shell > Profile > Notifications Center > Push Opt-In Alert` Tap No thanks to dismiss the opt-in alert | ✅ | ❌ | Not in the HarmonyOS function list. |
| 921 | `App Shell > Profile > Settings > About` Tap the About title 7 times to open Developer Settings | ✅ | ✅ |  |
| 922 | `App Shell > Profile > Settings > About` Tap /translatewiki.net to open translatewiki.net in the in-app web page | ❌ | ✅ | iOS About is a web page; its links are not listed as functions. |
| 923 | `App Shell > Profile > Settings > About` Tap the Libraries used link to open Libraries Used | ✅ | ✅ |  |
| 924 | `App Shell > Profile > Settings > About` Tap Gerrit to open the Gerrit repository in the in-app web page | ❌ | ✅ | iOS About is a web page; its links are not listed as functions. |
| 925 | `App Shell > Profile > Settings > About` Tap GitHub to open the GitHub repository in the in-app web page | ❌ | ✅ | iOS About is a web page; its links are not listed as functions. |
| 926 | `App Shell > Profile > Settings > About` Tap MIT License to open the license text in the in-app web page | ❌ | ✅ | iOS About is a web page; its links are not listed as functions. |
| 927 | `App Shell > Profile > Settings > About` Tap Creative Commons Attribution-ShareAlike License to open the license in the in-app web page | ❌ | ✅ | iOS About is a web page; its links are not listed as functions. |
| 928 | `App Shell > Profile > Settings > Account` Toggle Auto-sign discussions to save the talk page auto-sign preference | ✅ | ✅ |  |
| 929 | `App Shell > Profile > Settings > Account` Tap Vanish account to open the vanish account warning | ✅ | ❌ | HarmonyOS has no Vanish account flow. |
| 930 | `App Shell > Profile > Settings > Appearance` Select a theme option to change the reading theme | ✅ | ✅ | HarmonyOS lists each theme option as its own row. |
| 931 | `App Shell > Profile > Settings > Appearance` Drag the text size slider to change the article text size | ✅ | ✅ |  |
| 932 | `App Shell > Profile > Settings > Appearance` Toggle Image dimming to decrease image opacity on dark and black themes | ✅ | ✅ |  |
| 933 | `App Shell > Profile > Settings > Appearance` Toggle Expand tables to open all article tables by default | ✅ | ✅ |  |
| 934 | `App Shell > Profile > Settings > Appearance` Select Contributor to set it as the app icon | ✅ | ❌ | iOS alternate app icon; HarmonyOS offers no app icon choice. |
| 935 | `App Shell > Profile > Settings > Clear Cached Data Confirmation` Tap Clear cache to clear the cached data | ✅ | ✅ |  |
| 936 | `App Shell > Profile > Settings > Clear Cached Data Confirmation` Tap Cancel to dismiss the clear cache confirmation | ✅ | ✅ |  |
| 937 | `App Shell > Profile > Settings > Customize Explore Feed` Tap Turn off Explore feed to set Settings as the default tab and save the preferences | ✅ | ✅ |  |
| 938 | `App Shell > Profile > Settings > Customize Explore Feed` Tap Cancel on the turn-off alert to reject the new preferences | ✅ | ✅ |  |
| 939 | `App Shell > Profile > Settings > Customize Explore Feed` Tap Turn on Explore to save the preferences and set Explore as the default tab | ✅ | ✅ | HarmonyOS turns the Explore tab on with the toggle; no turn-on alert, #955. |
| 940 | `App Shell > Profile > Settings > Customize Explore Feed` Tap Cancel on the turn-on alert to reject the new preferences | ✅ | ❌ | HarmonyOS has no turn-on alert, so no Cancel on it. |
| 941 | `App Shell > Profile > Settings > Database Population` Toggle Create under Saved Articles | ✅ | ❌ | iOS debug-only Database Population tool; not in the HarmonyOS function list. |
| 942 | `App Shell > Profile > Settings > Database Population` Toggle Add under Saved Articles | ✅ | ❌ | iOS debug-only Database Population tool; not in the HarmonyOS function list. |
| 943 | `App Shell > Profile > Settings > Database Population` Toggle Randomize across languages under Saved Articles | ✅ | ❌ | iOS debug-only Database Population tool; not in the HarmonyOS function list. |
| 944 | `App Shell > Profile > Settings > Database Population` Toggle Add under Viewed Articles | ✅ | ❌ | iOS debug-only Database Population tool; not in the HarmonyOS function list. |
| 945 | `App Shell > Profile > Settings > Database Population` Toggle Randomize across languages under Viewed Articles | ✅ | ❌ | iOS debug-only Database Population tool; not in the HarmonyOS function list. |
| 946 | `App Shell > Profile > Settings > Database Population` Type values in the Viewed Article Dates fields | ✅ | ❌ | iOS debug-only Database Population tool; not in the HarmonyOS function list. |
| 947 | `App Shell > Profile > Settings > Database Population` Tap Do it to populate the database | ✅ | ❌ | iOS debug-only Database Population tool; not in the HarmonyOS function list. |
| 948 | `App Shell > Profile > Settings > Delete Donation History Confirmation` Tap Delete to delete the local donation history | ✅ | ✅ |  |
| 949 | `App Shell > Profile > Settings > Article syncing cover (unreachable)` Toggle Sync saved articles and lists in the article syncing cover | ❌ | ✅ | HarmonyOS article syncing cover that cannot be reached; not in the iOS list. |
| 950 | `App Shell > Profile > Settings > Delete Donation History Confirmation` Tap Cancel to dismiss the deletion confirmation | ✅ | ✅ |  |
| 951 | `App Shell > Profile > Settings > Donations` Tap Donation reminders to open the donation reminder settings | ✅ | ❌ | HarmonyOS has no donation reminder settings. |
| 952 | `App Shell > Profile > Settings > Donations` Tap Delete donation history to open the deletion confirmation | ✅ | ✅ | HarmonyOS puts Delete local donation history directly on the Settings page. |
| 953 | `App Shell > Profile > Settings > Erase Saved Articles` Tap the erase saved articles button | ✅ | ✅ |  |
| 954 | `App Shell > Profile > Settings > Storage and Syncing > Erase saved articles sheet` Tap the close button to dismiss the Erase saved articles sheet | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 955 | `App Shell > Profile > Settings > Explore Feed Settings` Toggle Explore tab to turn the Explore tab on or off | ✅ | ✅ |  |
| 956 | `App Shell > Profile > Settings > Help` Tap Report a bug to open an email compose with app details prefilled | ✅ | ✅ |  |
| 957 | `App Shell > Profile > Settings > Help` Tap Export User Data to open the share app library confirmation | ✅ | ✅ |  |
| 958 | `App Shell > Profile > Settings > Home Feed Settings` Tap Modules (Community) to open the community modules | ✅ | ✅ | HarmonyOS sends community modules to the Explore feed settings page. |
| 959 | `App Shell > Profile > Settings > Home Feed Settings` Tap Modules (For You) to open the For You modules | ✅ | ✅ | HarmonyOS has one Modules entry holding the For You toggles. |
| 960 | `App Shell > Profile > Settings > Home Feed Settings` Tap What's Driving your feed to open the What's Driving screen | ✅ | ✅ |  |
| 961 | `App Shell > Profile > Settings > Privacy and Terms` Tap Privacy policy to open the privacy policy | ✅ | ✅ |  |
| 962 | `App Shell > Profile > Settings > Privacy and Terms` Tap Terms of use to open the terms of use | ✅ | ✅ |  |
| 963 | `App Shell > Profile > Settings > Privacy and Terms` Tap Legal & safety contacts to open the external page | ✅ | ✅ |  |
| 964 | `App Shell > Profile > Settings > Push Notifications` Toggle Push notifications to turn push notifications on or off | ✅ | ✅ |  |
| 965 | `App Shell > Profile > Settings > Push Notifications` Tap Push notifications to open the system notification settings | ✅ | ✅ |  |
| 966 | `App Shell > Profile > Settings > Search Settings` Toggle Show languages on search to show or hide the language bar | ✅ | ✅ |  |
| 967 | `App Shell > Profile > Settings > Search Settings` Toggle Open app on Search tab to open the app on the Search tab | ✅ | ✅ |  |
| 968 | `Global` Relaunch the app to stay signed in with the saved login session | ❌ | ✅ | Login session persistence across launches; the iOS list does not count it as a function. |
| 969 | `App Shell > Profile > Settings > Storage and Syncing` Toggle Sync saved articles and lists to turn reading list syncing on or off | ✅ | ✅ | HarmonyOS lists turning sync on and off as separate rows. |
| 970 | `App Shell > Profile > Settings > Storage and Syncing` Toggle Show Saved reading list to show the default list as a separate list | ✅ | ✅ |  |
| 971 | `App Shell > Profile > Settings > Storage and Syncing` Tap Update synced reading lists to request a sync | ✅ | ✅ |  |
| 972 | `App Shell > Profile > Settings > Storage and Syncing` Tap Erase saved articles to open the Erase saved articles sheet | ❌ | ✅ | iOS erase is one button row; HarmonyOS adds a sheet, so opening it has no iOS row. |
| 973 | `App Shell > Profile > Settings > Year in Review Settings` Toggle Year in Review to show or hide the Year in Review | ✅ | ✅ |  |
| 974 | `App Shell > Profile > Settings > Preferred Languages` Tap Close (X icon) to close the Preferred Languages page | ❌ | ✅ | Close button; the iOS list does not count it as a function. |
| 975 | `App Shell > Profile > Watchlist > Filter` Select a project to include or exclude it in the Watchlist filter | ✅ | ✅ |  |
| 976 | `App Shell > Profile > Watchlist > Filter` Tap Add language... to open the Wikipedia languages list | ✅ | ✅ | HarmonyOS opens the preferred languages screen instead of the full languages list. |
| 977 | `App Shell > Profile > Watchlist > Filter` Select an option in a filter section (Latest revision, Activity, Automated contributions, Significance, User registration, Type of change) | ✅ | ✅ | HarmonyOS lists each filter section separately. |
| 978 | `App Shell > Profile > Watchlist > Filter` Tap Close (checkmark) to save the filter settings and dismiss the screen | ✅ | ✅ |  |
| 979 | `App Shell > Profile > Watchlist > User Chip Menu` Tap User page to open that user's page | ✅ | ✅ |  |
| 980 | `App Shell > Profile > Watchlist > User Chip Menu` Tap Talk page to open that user's talk page | ✅ | ✅ |  |
| 981 | `App Shell > Profile > Watchlist > User Chip Menu` Tap Contributions to open that user's contributions | ✅ | ✅ |  |
| 982 | `App Shell > Profile > Watchlist > User Chip Menu` Tap Thank to send thanks for the edit | ✅ | ✅ |  |
| 983 | `App Shell > Profile > Watchlist > User Chip Menu` Tap Diff to open the edit diff | ✅ | ✅ | No Diff item in the user menu; tapping the card opens the diff, #687. |
| 984 | `Explore > Article > Editor > Find and Replace Bar > Replace Type Menu` Select Replace to set the replace type to single replacement | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 985 | `Explore > Article > Editor > Find and Replace Bar > Replace Type Menu` Select Replace all to set the replace type to replace all matches | ✅ | ❌ | HarmonyOS editor has no find and replace. |
| 986 | `Explore > Article > Editor > Insert Media > Image Info Panel` Tap More information to open the image information page | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 987 | `Explore > Article > Editor > Insert Media > Media Settings` Tap Next (Add image details) to insert the image and open Preview | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 988 | `Explore > Article > Editor > Insert Media > Media Settings` Tap Insert to insert the image wikitext into the article | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 989 | `Explore > Article > Editor > Insert Media > Media Settings` Select an image position (Right, Left, Center or None) | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 990 | `Explore > Article > Editor > Insert Media > Media Settings` Select an image type (Thumbnail, Frameless, Frame or Basic) | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 991 | `Explore > Article > Editor > Insert Media > Media Settings` Select Custom image size (px) | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 992 | `Explore > Article > Editor > Insert Media > Media Settings` Type in the Caption field to set the image caption | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 993 | `Explore > Article > Editor > Insert Media > Media Settings` Type in the Alternative text field to describe the image | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 994 | `Explore > Article > Editor > Insert Media > Media Settings` Tap Learn more to open the help for the setting | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 995 | `Explore > Article > Editor > Insert Media > Media Settings` Tap Advanced settings to open Advanced Settings | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 996 | `Explore > Article > Editor > Insert Media > Media Settings` Tap the settings image row button | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 997 | `Explore > Article > Editor > Insert Media > Result Preview Menu` Tap Select image to select the image for insertion | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 998 | `Explore > Article > Editor > Insert Media > Result Preview Menu` Tap More information to open the image detail view | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 999 | `Explore > Article > Editor > Preview > Internal Link Not Found Alert` Tap OK to dismiss the No internal link found alert | ✅ | ❌ | HarmonyOS has no edit Preview screen. |
| 1000 | `Explore > Article > Editor > Preview > Internal Link Preview` Tap the dismiss button to close the internal link preview | ✅ | ❌ | HarmonyOS has no edit Preview screen. |
| 1001 | `Explore > Article > Editor > Preview > Link Popup` Tap OK to dismiss the link popup | ✅ | ❌ | HarmonyOS has no edit Preview screen. |
| 1002 | `Explore > Article > Editor > Preview > Publish Changes` Tap Publish to publish the edit | ✅ | ✅ | HarmonyOS publishes from the editor screen; no separate Publish Changes screen. |
| 1003 | `Explore > Article > Editor > Preview > Publish Changes` Toggle This is a minor edit to mark the edit as minor | ✅ | ❌ | HarmonyOS has no minor edit option. |
| 1004 | `Explore > Article > Editor > Preview > Publish Changes` Tap Learn more about minor edits to open the minor edit information | ✅ | ❌ | HarmonyOS has no minor edit option. |
| 1005 | `Explore > Article > Editor > Preview > Publish Changes` Tap Show web preview to show the web preview of the edit | ✅ | ❌ | HarmonyOS has no web preview of the edit. |
| 1006 | `Explore > Article > Editor > Preview > Publish Changes` Toggle Watch this page to add or remove the page on the watchlist | ✅ | ❌ | HarmonyOS publish flow has no Watch this page option. |
| 1007 | `Explore > Article > Editor > Preview > Publish Changes` Tap Learn more about your Watchlist to open the watchlist information | ✅ | ❌ | HarmonyOS publish flow has no Watch this page option. |
| 1008 | `Explore > Article > Editor > Preview > Publish Changes` Tap the Log in link in the terms text to open login | ✅ | ❌ | HarmonyOS publish flow has no inline Log in link. |
| 1009 | `Explore > Article > Editor > Preview > Publish Changes` Tap the Terms of Use or license link in the publishing notice | ✅ | ❌ | HarmonyOS publish flow has no Terms of Use or license notice. |
| 1010 | `Explore > Article > Editor > Text Formatting Keyboard > Heading Picker` Select Paragraph in the heading picker (no change to the text) | ✅ | ❌ | HarmonyOS editor has no heading picker. |
| 1011 | `Explore > Article > Editor > Text Formatting Keyboard > Heading Picker` Select Heading in the heading picker to format the line as a heading | ✅ | ❌ | HarmonyOS editor has no heading picker. |
| 1012 | `Explore > Article > Editor > Text Formatting Keyboard > Heading Picker` Select Subheading 1 in the heading picker to format the line as a level 3 heading | ✅ | ❌ | HarmonyOS editor has no heading picker. |
| 1013 | `Explore > Article > Editor > Text Formatting Keyboard > Heading Picker` Select Subheading 2 in the heading picker to format the line as a level 4 heading | ✅ | ❌ | HarmonyOS editor has no heading picker. |
| 1014 | `Explore > Article > Editor > Text Formatting Keyboard > Heading Picker` Select Subheading 3 in the heading picker to format the line as a level 5 heading | ✅ | ❌ | HarmonyOS editor has no heading picker. |
| 1015 | `Explore > Article > Editor > Text Formatting Keyboard > Heading Picker` Select Subheading 4 in the heading picker to format the line as a level 6 heading | ✅ | ❌ | HarmonyOS editor has no heading picker. |
| 1016 | `Explore > Article > Page History > Diff > Educational Panel` Tap Got it to dismiss the Comparing revisions panel | ✅ | ❌ | HarmonyOS diff has no educational panel. |
| 1017 | `Explore > Article > Page History > Diff > More Menu` Tap Rollback to open the Rollback alert | ✅ | ❌ | HarmonyOS diff has no More menu. |
| 1018 | `Explore > Article > Page History > Diff > More Menu` Tap Share to open the share sheet with the diff URL | ✅ | ❌ | HarmonyOS diff has no More menu. |
| 1019 | `Explore > Article > Page History > Diff > More Menu` Tap Watch to add the page to the watchlist | ✅ | ❌ | HarmonyOS diff has no More menu. |
| 1020 | `Explore > Article > Page History > Diff > More Menu` Tap Unwatch to remove the page from the watchlist | ✅ | ❌ | HarmonyOS diff has no More menu. |
| 1021 | `Explore > Article > Page History > Diff > More Menu` Tap Edit history to open Page History for the article | ✅ | ❌ | HarmonyOS diff has no More menu. |
| 1022 | `Explore > Article > Page History > Diff > More Menu` Tap Undo to open the Undo alert | ✅ | ❌ | HarmonyOS diff has no More menu. |
| 1023 | `Explore > Article > Page History > Diff > Rollback Alert` Tap Cancel to dismiss the Rollback alert | ✅ | ❌ | HarmonyOS diff has no Rollback. |
| 1024 | `Explore > Article > Page History > Diff > Rollback Alert` Tap Rollback to roll back the edits | ✅ | ❌ | HarmonyOS diff has no Rollback. |
| 1025 | `Explore > Article > Page History > Diff > Thanks Education Panel` Tap Send Thanks to publicly send Thanks for the edit | ✅ | ❌ | HarmonyOS diff has no Thanks flow; thanks are sent from the Watchlist user menu. |
| 1026 | `Explore > Article > Page History > Diff > Thanks Education Panel` Tap Cancel to dismiss the Thanks education panel | ✅ | ❌ | HarmonyOS diff has no Thanks flow; thanks are sent from the Watchlist user menu. |
| 1027 | `Explore > Article > Page History > Diff > Thanks Login Alert` Tap Log in or create account to open login and resend Thanks | ✅ | ❌ | HarmonyOS diff has no Thanks flow; thanks are sent from the Watchlist user menu. |
| 1028 | `Explore > Article > Page History > Diff > Thanks Login Alert` Tap Cancel to dismiss the Thanks login alert | ✅ | ❌ | HarmonyOS diff has no Thanks flow; thanks are sent from the Watchlist user menu. |
| 1029 | `Explore > Article > Page History > Diff > Undo Alert` Type a reason in the Undo summary field | ✅ | ❌ | HarmonyOS diff has no Undo. |
| 1030 | `Explore > Article > Page History > Diff > Undo Alert` Tap Cancel to dismiss the Undo alert | ✅ | ❌ | HarmonyOS diff has no Undo. |
| 1031 | `Explore > Article > Page History > Diff > Undo Alert` Tap Undo to undo the revision with the given reason | ✅ | ❌ | HarmonyOS diff has no Undo. |
| 1032 | `Explore > Article > Talk Page > New Topic > Discard Sheet` Tap Discard Topic to discard the topic and close New Topic | ✅ | ✅ |  |
| 1033 | `Explore > Article > Talk Page > New Topic > Discard Sheet` Tap Keep Editing to dismiss the sheet and keep the topic | ✅ | ✅ |  |
| 1034 | `Explore > Article > Talk Page > Reply Compose > Discard Sheet` Tap Discard Reply to discard the reply and close compose | ✅ | ❌ | HarmonyOS talk page has no reply function. |
| 1035 | `Explore > Article > Talk Page > Reply Compose > Discard Sheet` Tap Keep Editing to dismiss the sheet and keep the reply | ✅ | ❌ | HarmonyOS talk page has no reply function. |
| 1036 | `App Shell > Profile > Log In > Two-Factor Login > Auto-Login Sheet` Tap Cancel to dismiss the verification sheet and log out | ✅ | ❌ | Not in the HarmonyOS function list. |
| 1037 | `App Shell > Profile > Settings > About > Developer Settings` Toggle Enable Developer Mode to switch developer mode | ✅ | ❌ | The HarmonyOS developer menu has no developer mode toggle. |
| 1038 | `App Shell > Profile > Settings > About > Libraries Used` Tap a library row to open its license text | ✅ | ❌ | HarmonyOS shows library names as plain text; rows do not open license text. |
| 1039 | `App Shell > Profile > Settings > Account > Vanish Warning` Tap Continue to start the account vanish flow | ✅ | ❌ | HarmonyOS has no Vanish account flow. |
| 1040 | `App Shell > Profile > Settings > Account > Vanish Warning` Tap Cancel to dismiss the vanish warning | ✅ | ❌ | HarmonyOS has no Vanish account flow. |
| 1041 | `App Shell > Profile > Settings > Account > Vanish Warning` Swipe down on the vanish warning sheet to dismiss it | ✅ | ❌ | HarmonyOS has no Vanish account flow. |
| 1042 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the In the news card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1043 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Featured article card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1044 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Top read card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1045 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the On this day card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1046 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Picture of the day card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1047 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Places card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1048 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Randomizer card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1049 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Continue reading card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1050 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Because you read card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1051 | `Explore > Explore Feed Settings` Tap a language toggle to turn that language's feed cards on or off | ❌ | ✅ | iOS function list has no per-language Explore feed toggle. |
| 1052 | `Explore > Explore Feed Settings` Tap the Global cards toggle to turn global feed cards on or off | ❌ | ✅ | iOS function list has no Global cards toggle. |
| 1053 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Suggested edits card | ✅ | ❌ | HarmonyOS feed settings have no Suggested edits card. |
| 1054 | `App Shell > Profile > Settings > Explore Feed Settings > Card Detail` Toggle the Games card | ✅ | ✅ | HarmonyOS opens each card's settings page and uses its Show card toggle. |
| 1055 | `App Shell > Profile > Settings > Explore Feed Settings > Explore Tab Alert` Tap Turn on Explore to enable all cards and set Explore as the default tab | ✅ | ✅ | HarmonyOS turns the Explore tab on with the toggle; no turn-on alert, #955. |
| 1056 | `App Shell > Profile > Settings > Explore Feed Settings > Explore Tab Alert` Tap Cancel to keep the Explore tab off | ✅ | ❌ | HarmonyOS has no turn-on alert, so no Cancel on it. |
| 1057 | `App Shell > Profile > Settings > Explore Feed Settings > Explore Tab Alert` Tap Turn off Explore to disable all cards and set Settings as the default tab | ✅ | ✅ |  |
| 1058 | `App Shell > Profile > Settings > Explore Feed Settings > Explore Tab Alert` Tap Cancel to keep the Explore tab on | ✅ | ✅ |  |
| 1059 | `App Shell > Profile > Settings > Help > Export User Data Confirmation` Tap Share to export and share the app library | ✅ | ✅ | HarmonyOS copies the app library location instead of opening a share sheet. |
| 1060 | `App Shell > Profile > Settings > Help > Export User Data Confirmation` Tap Cancel to dismiss the share confirmation | ✅ | ✅ |  |
| 1061 | `App Shell > Profile > Settings > Home Feed Settings > Whats Driving Feed` Tap Your interests to open the Your Interests page | ✅ | ✅ | HarmonyOS opens the Explore feed settings instead of a Your Interests page. |
| 1062 | `App Shell > Profile > Settings > Home Feed Settings > Whats Driving Feed` Tap Reading history | ✅ | ✅ |  |
| 1063 | `App Shell > Profile > Settings > Home Feed Settings > Whats Driving Feed` Tap Languages | ✅ | ✅ |  |
| 1064 | `App Shell > Profile > Settings > Push Notifications > Permission Error Alert` Tap OK to dismiss the notification subscription error alert | ✅ | ❌ | Not in the HarmonyOS function list. |
| 1065 | `App Shell > Profile > Settings > Storage and Syncing > Disable Sync Alert` Tap Yes to turn off reading list syncing and delete the synced lists | ✅ | ✅ |  |
| 1066 | `App Shell > Profile > Settings > Storage and Syncing > Disable Sync Alert` Tap No to keep reading list syncing on | ✅ | ✅ |  |
| 1067 | `App Shell > Profile > Settings > Storage and Syncing > Sync Panel` Tap Enable syncing to turn on reading list syncing | ✅ | ✅ | HarmonyOS has no sync panel; syncing is switched by the toggle alone, #969. |
| 1068 | `App Shell > Profile > Settings > Storage and Syncing > Sync Panel` Tap Cancel to dismiss the sync panel | ✅ | ❌ | HarmonyOS has no sync panel; syncing is switched by the toggle alone. |
| 1069 | `App Shell > Profile > Settings > Storage and Syncing > Sync Panel` Tap Yes, add them to my reading lists to merge saved articles into reading lists | ✅ | ❌ | HarmonyOS has no sync panel; syncing is switched by the toggle alone. |
| 1070 | `App Shell > Profile > Settings > Storage and Syncing > Sync Panel` Tap No, delete articles from device to delete the saved articles | ✅ | ❌ | HarmonyOS has no sync panel; syncing is switched by the toggle alone. |
| 1071 | `App Shell > Profile > Settings > Storage and Syncing > Sync Panel` Tap Got it to dismiss the sync status panel | ✅ | ❌ | HarmonyOS has no sync panel; syncing is switched by the toggle alone. |
| 1072 | `App Shell > Profile > Watchlist > Filter > Add Language` Tap a language to add it to the preferred languages and return to the filter | ✅ | ✅ | HarmonyOS adds languages via preferred languages, then the Languages page, #512. |
| 1073 | `Explore > Article > Editor > Insert Media > Media Settings > Advanced Settings` Toggle Wrap text around image to enable or disable the Image position row | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 1074 | `Explore > Article > Editor > Insert Media > Media Settings > Advanced Settings` Tap Image position to open its settings list | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 1075 | `Explore > Article > Editor > Insert Media > Media Settings > Advanced Settings` Tap Image type to open its settings list | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 1076 | `Explore > Article > Editor > Insert Media > Media Settings > Advanced Settings` Tap Image size to open the Image Size settings | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 1077 | `Explore > Article > Editor > Preview > Publish Changes > Abuse Filter Panel` Tap Go back to return to editing after an abuse filter response | ✅ | ❌ | HarmonyOS has no abuse filter panel. |
| 1078 | `Explore > Article > Editor > Preview > Publish Changes > Abuse Filter Panel` Tap Publish anyway to publish despite the abuse filter warning | ✅ | ❌ | HarmonyOS has no abuse filter panel. |
| 1079 | `Explore > Article > Editor > Preview > Publish Changes > Abuse Filter Panel` Tap OK to dismiss the blocked panel | ✅ | ❌ | HarmonyOS has no abuse filter panel. |
| 1080 | `Explore > Article > Editor > Preview > Publish Changes > Edit Summary` Tap Fixed typo to fill the edit summary field | ✅ | ❌ | HarmonyOS has only a free-text edit summary; no canned summary buttons. |
| 1081 | `Explore > Article > Editor > Preview > Publish Changes > Edit Summary` Tap Fixed grammar to fill the edit summary field | ✅ | ❌ | HarmonyOS has only a free-text edit summary; no canned summary buttons. |
| 1082 | `Explore > Article > Editor > Preview > Publish Changes > Edit Summary` Tap Added links to fill the edit summary field | ✅ | ❌ | HarmonyOS has only a free-text edit summary; no canned summary buttons. |
| 1083 | `Explore > Article > Editor > Preview > Publish Changes > Edit Summary` Tap Added image to fill the edit summary field | ✅ | ❌ | HarmonyOS has only a free-text edit summary; no canned summary buttons. |
| 1084 | `Explore > Article > Editor > Preview > Publish Changes > Edit Summary` Tap Added image and caption to fill the edit summary field | ✅ | ❌ | HarmonyOS has only a free-text edit summary; no canned summary buttons. |
| 1085 | `Explore > Article > Editor > Preview > Publish Changes > Edit Summary` Type in the Add an edit summary field (up to 255 characters) | ✅ | ✅ |  |
| 1086 | `Explore > Article > Editor > Preview > Publish Changes > Edit Summary` Tap Learn more to open the edit summary information | ✅ | ❌ | HarmonyOS has no edit summary Learn more link. |
| 1087 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Toggle Bypass donation | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1088 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Toggle Bypass Reminder Daily Limit | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1089 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Toggle Override Current Date to show the date picker | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1090 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Select a date in the graphical date picker to override the current date | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1091 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Toggle Force Fundraising Campaign Banner | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1092 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Toggle Use Test Wiki Donate Configs | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1093 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Toggle Use Hardcoded Payment Methods | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1094 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Select a Force Reminder Experiment Group option (Off, Control (A), Group B, Group C) | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1095 | `App Shell > Profile > Settings > About > Developer Settings > Fundraising` Tap Clear banner prompt state and donation history to reset donation state | ✅ | ❌ | iOS developer fundraising option; the HarmonyOS developer menu lacks it. |
| 1096 | `App Shell > Profile > Settings > About > Developer Settings > Semantic Search` Toggle Enable Semantic Search | ✅ | ❌ | iOS developer semantic search option; the HarmonyOS developer menu lacks it. |
| 1097 | `App Shell > Profile > Settings > About > Developer Settings > Semantic Search` Select a Force Experiment Group option (Off, Control (A), Group B) | ✅ | ❌ | iOS developer semantic search option; the HarmonyOS developer menu lacks it. |
| 1098 | `App Shell > Profile > Settings > About > Developer Settings > Semantic Search` Tap Clear experiment assignment to reset the experiment assignment | ✅ | ❌ | iOS developer semantic search option; the HarmonyOS developer menu lacks it. |
| 1099 | `App Shell > Profile > Settings > About > Developer Settings > Semantic Search` Tap Reset entry point to reset the semantic search entry point | ✅ | ❌ | iOS developer semantic search option; the HarmonyOS developer menu lacks it. |
| 1100 | `App Shell > Profile > Settings > About > Developer Settings > Widgets` Tap Clear cache and reload widgets to clear the widget cache | ✅ | ❌ | iOS widget tool; the HarmonyOS port has no widgets. |
| 1101 | `App Shell > Profile > Settings > About > Developer Settings > Year in Review` Toggle Show Year in Review 2026 to enable the Year in Review test controls | ✅ | ✅ | HarmonyOS developer menu has a single Show/Hide Year in Review action. |
| 1102 | `App Shell > Profile > Settings > About > Developer Settings` Tap Clear games persistence to clear stored games data | ❌ | ✅ | HarmonyOS-only developer setting. |
| 1103 | `App Shell > Profile > Settings > About > Developer Settings` Tap Force email auth to toggle forced email authentication | ❌ | ✅ | HarmonyOS-only developer setting. |
| 1104 | `App Shell > Profile > Settings > About > Developer Settings` Tap Cancel to dismiss the Developer Settings menu | ❌ | ✅ | Cancel button; the iOS list does not count it as a function. |
| 1105 | `App Shell > Profile > Settings > About > Developer Settings > Year in Review` Select a Force Experience option (Off, Data Rich Experience, Data Low Experience) | ✅ | ❌ | The HarmonyOS developer menu has no Year in Review experience override. |
| 1106 | `App Shell > Profile > Settings > About > Developer Settings > Year in Review` Toggle Force Year in Review 2026 Announcement to force the announcement | ✅ | ❌ | The HarmonyOS developer menu has no forced announcement option. |
| 1107 | `App Shell > Profile > Settings > Home Feed Settings > Home Feed Modules > Community` Toggle Featured article | ✅ | ✅ | HarmonyOS toggles community cards in each Explore feed card's settings page. |
| 1108 | `App Shell > Profile > Settings > Home Feed Settings > Home Feed Modules > Community` Toggle Top read | ✅ | ✅ | HarmonyOS toggles community cards in each Explore feed card's settings page. |
| 1109 | `App Shell > Profile > Settings > Home Feed Settings > Home Feed Modules > Community` Toggle In the news | ✅ | ✅ | HarmonyOS toggles community cards in each Explore feed card's settings page. |
| 1110 | `App Shell > Profile > Settings > Home Feed Settings > Home Feed Modules > Community` Toggle On this day | ✅ | ✅ | HarmonyOS toggles community cards in each Explore feed card's settings page. |
| 1111 | `App Shell > Profile > Settings > Home Feed Settings > Home Feed Modules > Community` Toggle Picture of the day | ✅ | ✅ | HarmonyOS toggles community cards in each Explore feed card's settings page. |
| 1112 | `Explore > Explore Feed Settings > Feed Card Settings` Tap a language toggle to turn this card kind on or off for that language | ❌ | ✅ | iOS function list has no per-language toggle in card settings. |
| 1113 | `App Shell > Profile > Settings > Home Feed Settings > Home Feed Modules > For You` Toggle Based on your interests | ✅ | ✅ |  |
| 1114 | `App Shell > Profile > Settings > Home Feed Settings > Home Feed Modules > For You` Toggle Because you read | ✅ | ✅ |  |
| 1115 | `App Shell > Profile > Settings > Home Feed Settings > Home Feed Modules > For You` Toggle Continue reading | ✅ | ✅ |  |
| 1116 | `App Shell > Profile > Settings > Home Feed Settings > Whats Driving Feed > Your Interests` Type in the Search for an article field to search articles to add as interests | ✅ | ❌ | HarmonyOS has no Your Interests page. |
| 1117 | `App Shell > Profile > Settings > Home Feed Settings > Whats Driving Feed > Your Interests` Tap Deselect all to clear all selected topics | ✅ | ❌ | HarmonyOS has no Your Interests page. |
| 1118 | `App Shell > Profile > Settings > Home Feed Settings > Whats Driving Feed > Your Interests` Select a topic chip to select or deselect the topic and load its articles | ✅ | ❌ | HarmonyOS has no Your Interests page. |
| 1119 | `App Shell > Profile > Settings > Home Feed Settings > Whats Driving Feed > Your Interests` Tap an article card in the interests grid | ✅ | ❌ | HarmonyOS has no Your Interests page. |
| 1120 | `Explore > Article > Editor > Insert Media > Media Settings > Advanced Settings > Image Size` Select Width or Height as the size measure | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 1121 | `Explore > Article > Editor > Insert Media > Media Settings > Advanced Settings > Image Size` Toggle the custom size switch | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
| 1122 | `Explore > Article > Editor > Insert Media > Media Settings > Advanced Settings > Image Size` Type a pixel value in the Width (px) field | ✅ | ❌ | HarmonyOS editor has no Insert Media feature. |
