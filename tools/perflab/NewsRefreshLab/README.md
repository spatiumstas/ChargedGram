# News refresh overlay lab

This small AppKit app compiles copies of the production News refresh indicator, gesture controller, list view, new-posts pill, and reveal model against the real TGUIKit. It verifies a centered, fixed-size overlay without building Telegram.

The refresh indicator stays at 44 pt in a stable frame, 8 pt below the list header, and triggers at an independent 13.5 pt pull distance. A small scale-and-opacity reveal replaces resizing the indicator to fit the elastic gap. Loading does not shift the list's clip-view frame. The new-posts pill is suppressed while the overlay is visible and restored according to its latest state after cancellation or completion.

## Run

```sh
python3 tools/perflab/NewsRefreshLab/prepare.py
swift test --package-path tools/perflab/NewsRefreshLab --scratch-path /tmp/NewsRefreshLab-build
swift test -c release --package-path tools/perflab/NewsRefreshLab --scratch-path /tmp/NewsRefreshLab-release
swift test --sanitize=address --package-path tools/perflab/NewsRefreshLab --scratch-path /tmp/NewsRefreshLab-asan
```

The 18 tests cover reveal bounds and monotonicity, full-size geometry throughout pulling and loading, one refresh at 13.5 pt, momentum rejection, mid-feed gesture rejection, cancellation, pill suppression and updates, resizing, mouse transparency, unrelated list scrolling, disabled refresh, no list displacement during loading, and completion releasing pending updates.

The preparation script records production source hashes. It removes Telegram-only imports, widens access to the scroll and completion test entry points, and substitutes the elastic document-offset read with a controlled test value. AppKit clamps programmatically assigned offsets at the content boundary, so the tests cannot use those assignments to simulate a real trackpad's elastic overscroll. Actual AppKit views, layers, frame placement, gesture notifications, and animation completion are used.

Lottie and the application theme boundary are adapters. Tests do not execute TelegramMedia's Lottie player or fetch a real News feed. The preview adapter displays frame 179 of the actual bundled `news_drop.tgs`, tinted to the accent color. It does not simulate the loading Lottie playback. Physical trackpad feel and a full app build remain manual checks.

## Preview

Use an existing rlottie shared library to render the icon, then run the mini-app:

```sh
python3 tools/perflab/NewsRefreshLab/render_icon.py /path/to/librlottie.dylib /tmp/news-refresh-icon.bgra
swift run --package-path tools/perflab/NewsRefreshLab --scratch-path /tmp/NewsRefreshLab-build NewsRefreshPreview /tmp/news-refresh-previews /tmp/news-refresh-icon.bgra
```

The app briefly opens temporary windows and writes previews at 2, 5, 9 and 13.5 pt pull distances. The images use sample feed text and the production overlay/list views.

Progress changes explicitly animate `strokeEnd` for 120 ms from the currently displayed value, including when a pull reverses. Repeated identical progress does not restart the animation. The completion burst waits for that fill animation, while the refresh request starts immediately. Additional AppKit tests cover the animation itself, visible-value retargeting, repeat suppression, burst sequencing, and reset cleanup.
