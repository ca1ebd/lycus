# 0003: Playwright's own browsers, never apt chromium

Date: 2026-09-05
Status: Accepted

## Context

The agent needs a browser. The obvious instruction — "install chromium from
apt" — does not do what it sounds like on Ubuntu.

`chromium-browser` is a transitional stub whose only job is to install the snap
— `2:1snap1-0ubuntu2` on 24.04, still `2:1snap1-0ubuntu4` on 26.04. Ubuntu ships
no real apt chromium. So "apt chromium" means "the snap", and the snap declares
`cups` as a runtime dependency via a content interface.

On the original host that produced a full print server listening on
`0.0.0.0:631` and `[::]:631` — on a machine with no printer, whose public
address sat directly on `eth0` with no host firewall. Nobody asked for a print
server; it arrived as a transitive dependency of a browser.

Meanwhile the agent never used that browser. It drives Playwright's own
downloaded builds under `~/.cache/ms-playwright`; nothing in its config
referenced `/snap/bin/chromium`, and `browser.engine` was `auto` with an empty
`cdp_url`.

## Decision

Install Playwright's browsers with `playwright install`, and use apt only for
the system library and font layer they link against — `libnss3`, `libatk*`,
`libgbm1`, `libasound2t64`, the gstreamer set, the font packages, `xvfb`.

The `devtools` role also removes the `cups` snap if present.

## Consequences

The browser stack is the one the agent actually uses, pinned by Playwright
rather than by Ubuntu's release cycle, and no print server appears.

Browsers now live in a cache directory (~948 MB) rather than in packages, which
is why `backup/capture.sh` deliberately excludes `~/.cache/ms-playwright`:
`playwright install` regenerates it, and copying it would carry a large
rebuildable blob between hosts for nothing.

The tradeoff is that browser updates are no longer handled by
`unattended-upgrades`. Refreshing them is a `playwright install` away, but it is
a deliberate act. For a headless automation host driven by a pinned client
library, matching the library's expected build is worth more than automatic
updates to a browser nothing points at.
