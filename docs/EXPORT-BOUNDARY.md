# The export boundary: the product is strictly the repository

What this repo **ships** and what this repo **uses to develop itself** are two
different things that currently live in the same directory. This file draws the
line, and records a change in how the line is enforced.

## The change

Release flow and Spec Kit used to be **partially enabled on the passthrough** —
some of each rode along into repos that consumed this one. They are now
**completely stripped**. Both stay in this repo; both serve **only the
development of this repo**.

Nothing about that removes them here. The engine is still developed with Spec
Kit, still specs its own features under `specs/`, still runs its own check gate.
It just stops handing any of that to a consumer.

## The principle

**The product is strictly the repository, and the export boundary is the repo
boundary.** Everything that exists to develop this repo — its Spec Kit install,
its own `specs/`, its release flow, its check gate, its agent configuration — is
development apparatus. Apparatus never crosses into a consumer.

What crosses is the extension payload and nothing else:

```
.specify/extensions/<name>/     # PRODUCT — extension.yml, commands/, scripts/, README
everything else                 # APPARATUS — dev-only, never exported
```

That includes `.specify/` templates and scripts, this repo's own
`.specify/extensions.yml` wiring, `specs/`, `.claude/`, `catalog.json`
machinery, and any workflow or release configuration added later.

## The rules are permissive now, not prohibitive

The old shape was a **denylist** — enumerate what to strip. That fails open: a
new file nobody thought to name is exported by default, and the failure is
silent. The failure mode is not hypothetical; it is how "partially enabled"
happened in the first place.

The new shape is **permissive**: nothing exports unless it is explicitly the
repository's designated product. Everything else is dev-only by default, and no
enumeration is required to keep it that way. Tooling added tomorrow is
non-exporting automatically, without anyone remembering to add it to a list.

Practically, when adding anything to this repo, the question is not "should this
be stripped?" It is "is this part of an extension payload?" If the answer is no,
it is already correctly excluded and there is nothing to do.

## Why it matters

A consumer that inherits this repo's development apparatus gets tooling it never
asked for, pinned at whatever version this repo happened to hold — a fork that
drifts silently from the real upstream, which the consumer then has to discover
and unpick.

The ecosystem already reached this conclusion once from the other direction:
`snackbyte-base` deliberately deletes `.specify/`, the `.claude/speckit-*`
mirrors, `specs/`, and `CLAUDE.md` when it resolves a spun-up app, on exactly
this reasoning — Spec Kit is installed per repo, on its own schedule, and a copy
shipped inside a template is a pinned fork. This file applies the same rule to
the engine, so both directions of the ecosystem agree: **development apparatus
is per-repo and never travels.**
