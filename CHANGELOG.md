# 3.0.0

**Major rewrite of 4chan X.**

Header:
 - Easily access features and the boards list directly from the Header.
 - The board list can be customized.
 - The Header can be automatically hidden.

Egocentrism:
 - `(You)` will be added to quotes linking to your posts.
 - The Unread tab icon will indicate new unread posts quoting you with an exclamation mark.
 - Delete links in the post menu will only appear for your posts.

Quick Reply changes:
 - Opening text files will insert their content in the comment field.
 - Pasting files/images (e.g. from another website) in Chrome will open them in the QR.
 - Cooldown start time is now more accurate, which means shorter cooldown period and faster auto-posting.
 - Cooldown remaining time will adjust to your upload speed and file size for faster auto-posting.
 - Clicking the submit button while uploading will abort the upload and won't start re-uploading automatically anymore.
 - Closing the QR while uploading will abort the upload and won't close the QR anymore.
 - Creating threads outside of the index is now possible.
 - Selection-to-quote also applies to selected text inside the post, not just inside the comment.
 - Added thumbnailing support for Opera.

Image Expansion changes:
 - The toggle and settings are now located in the Header's shortcuts and menu.
 - There is now a setting to allow expanding spoilers.
 - Expanding OP images won't squish replies anymore.

Thread Updater changes:
 - The Thread Updater will now notify of sticky/closed status change and update the icons.
 - The Thread Updater will pause when offline, and resume when online.
 - Added a setting to always auto-scroll to the bottom instead of the first new post.

Unread posts changes:
 - Added a line to distinguish read posts from unread ones.
 - Read posts won't be marked as unread after reloading a thread.
 - The page will scroll to the last read post after reloading a thread.
 - Visible posts will not be taken into account towards the unread count.

Thread Stats changes:
 - Post and file count will now adjust with deleted posts.
 - The post count will now become red past the bump limit.
 - The file count will not become red anymore inside sticky threads.

Thread/Post Hiding changes:
 - Added Thread & Post Hiding in the Menu, with individual settings.
 - Thread & Post Hiding Buttons can now be disabled in the settings.
 - Recursive Hiding will be automatically applied when manually showing/hiding a post.

Other:
 - Added touch and multi-touch support for dragging windows.
 - Added [eqn] and [math] tags keybind.
 - Fix Chrome's install warning saying that 4chan X would execute on all domains.
 - Fix Quote Backlinks and Quote Highlighting not affecting inlined quotes.
 - Fix unreadable inlined posts with the Tomorrow theme.
 - Fix user ID highlighting on fetched posts.
 - More fixes and improvements.
