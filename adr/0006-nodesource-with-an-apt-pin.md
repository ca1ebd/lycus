# 0006: Node from NodeSource, with an apt pin that actually binds

Date: 2026-09-05
Status: Accepted

## Context

The role added NodeSource's apt repository and installed `nodejs` from it. That
is what it looked like it did. What it actually did was add the repository and
then ignore it.

An apt repository added without a pin sits at priority 500 — the same as the
distribution archive. Apt breaks that tie by version number, so whichever source
happens to offer the higher version wins. On Ubuntu 24.04 that was NodeSource
(Node 20 beat the archive's Node 18) and everything appeared to work. On 26.04
the archive ships Node 22.22.1, which beats NodeSource's `node_20.x`, so the
distribution's package won instead.

Two things then broke at once, and only the second was visible:

1. The host got a different Node major than `devtools_node_major` asked for. No
   error — the variable simply stopped meaning anything.
2. `npm` disappeared. Debian and Ubuntu split `npm` into its own package;
   NodeSource bundles it inside `nodejs`. A later task failed with
   "Failed to find required executable npm", three tasks away from the cause.

So the role never controlled the Node version at all. On 24.04 it was correct by
coincidence.

## Decision

Keep NodeSource, and pin it so the repository actually binds:

```
Package: nodejs
Pin: origin deb.nodesource.com
Pin-Priority: 1001
```

Priority above 1000 is deliberate — that is the threshold at which apt will
install a package whose version number is *lower* than another source's, which
is precisely the case here.

The install uses `state: latest` rather than `present`. `present` is satisfied by
any `nodejs`, so on a host where the distribution's package is already installed
apt has no reason to act and the pin accomplishes nothing. `latest` means "the
pinned candidate".

`devtools_node_major` defaults to 22 — the current LTS. A task asserts the
installed major actually matches it, so a future silent skew fails at the Node
task with a clear message instead of surfacing later as a missing executable.

### Alternative considered and rejected: just use the distribution's packages

This was the first instinct, and it is genuinely attractive: no third-party
repository, no GPG key, no pin, no `state: latest`, and security updates arrive
through `unattended-upgrades` like everything else. Ubuntu 26.04's Node 22 is
the current LTS, so the version argument for NodeSource largely evaporates.

It was rejected on **npm**, not node. The archive's `npm` is `9.2.0~ds3-1` — a
separately-packaged, years-old npm paired with Node 22, which is not a
combination upstream tests. NodeSource ships node and a matching npm 10.x
together. Since npm is what actually runs here (`@devcontainers/cli`,
`npx playwright install`), the matched pair is worth the pin.

If npm ever stops mattering on this host, revisit — the distribution route is
strictly simpler and this ADR should be reversed rather than worked around.

## Consequences

`devtools_node_major` is now a real lever: changing it changes the installed
Node, because the pin makes NodeSource win regardless of what the archive offers.

`state: latest` means a new NodeSource patch release shows up as a changed task
on a later run, so the role is not perfectly idempotent over time. That is the
accepted cost of actually controlling the version. Pinning an exact version
string would restore idempotence but drift silently out of date, which is the
same class of problem this ADR exists to fix.

The pin is narrow — `Package: nodejs` only. NodeSource is not made preferred for
anything else it might ever publish.
