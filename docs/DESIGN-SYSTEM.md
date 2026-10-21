# Design System

Evidence Desk uses a quiet, editorial visual language: typography, spacing and
alignment carry the hierarchy; decoration does not.

## Source of truth

`EvidenceDesk/DesignSystem/DesignTokens.swift` defines every token. Views must
not introduce ad-hoc colors or magic sizes.

## Tokens

### Spacing (4 pt base)

| Token | Value |
| --- | --- |
| `Spacing.xs` | 4 |
| `Spacing.sm` | 8 |
| `Spacing.md` | 12 |
| `Spacing.lg` | 16 |
| `Spacing.xl` | 24 |
| `Spacing.xxl` | 32 |

### Radius

`Radius.small` 6, `Radius.medium` 10, `Radius.large` 12.

### Layout

| Token | Value | Purpose |
| --- | --- | --- |
| `Layout.defaultWindowWidth/Height` | 1180 × 780 | default window |
| `Layout.minWindowWidth/Height` | 980 × 640 | minimum usable window |
| `Layout.sidebarWidth` | 240 | library sidebar |
| `Layout.inspectorWidth` | 280 | optional inspector |
| `Layout.rowHeight` | 28 | list row rhythm |

### Color

Colors map to **system semantic colors** wherever possible, so light/dark and
accessibility settings are handled by AppKit:

| Token | Light source | Role |
| --- | --- | --- |
| `canvas` | `windowBackgroundColor` | page background |
| `surface` | `controlBackgroundColor` | cards / fields |
| `elevatedSurface` | `underPageBackgroundColor` | floating feedback |
| `separator` | `separatorColor` | rules and strokes |
| `primaryText` | `labelColor` | body text |
| `secondaryText` | `secondaryLabelColor` | supporting text |
| `tertiaryText` | `tertiaryLabelColor` | metadata |
| `accent` | `controlAccentColor` | actions, links |

Semantic evidence/finding colors use fixed, contrast-checked hues that differ
between appearances:

| Token | Light | Dark | Meaning |
| --- | --- | --- | --- |
| `fact` | deep green | light green | source explicitly states it |
| `inference` | steel blue | pale blue | interpretation |
| `hypothesis` | amber-brown | warm amber | unverified hypothesis |
| `unresolved` | deep red-brown | dusty red | open question |
| `success` | `.green` | `systemGreen` | supports / saved |
| `danger` | `.red` | `systemRed` | contradicts / destructive |

**Never color-only.** Every semantic state is rendered by `StatusTagView` with
an SF Symbol *and* a text label, so VoiceOver and grayscale users get the same
information.

### Typography

System fonts only, via semantic text styles:

`pageTitle` (largeTitle bold), `sectionTitle` (title3 semibold), `body` (body),
`secondary` (callout), `metadata` (caption medium), `monospacedSmall` (caption
monospaced, used for short codes and the report preview).

## Components

| Component | File | Notes |
| --- | --- | --- |
| `EmptyStateView` | `Components/EmptyStateView.swift` | icon + explanation + first action |
| `ErrorBannerView` | `Components/ErrorBannerView.swift` | message + optional retry |
| `InlineErrorText` | same file | form-level validation |
| `StatusTagView` | `Components/StatusTagView.swift` | label + symbol + color |
| `SaveStateIndicator` | `Components/SaveStateIndicator.swift` | idle/saving/saved/failed |
| `SectionHeader` | `Components/SectionHeader.swift` | consistent headings |
| `DetailRow` / `StatCard` | feature views | label/value pairs |

## Appearance rules

- Use `designAware()` at the window root to inject appearance-aware colors.
- Do not place text on colored fills without checking both appearances.
- Use `Divider`/`separator` for structure instead of shadows and boxes.
- Avoid glass effects on content; content legibility wins.
- Respect Reduce Motion: the app uses system navigation transitions only and
  adds no custom animations, so enabling Reduce Motion changes nothing that
  matters.
- No emoji as functional icons; SF Symbols only.

## Accessibility contract

- Icon-only buttons always carry `.help(...)` and a `Label`.
- Rows combine their children (`.accessibilityElement(children: .combine)`) and
  are described by their short code plus content.
- Save and error feedback is text, not just color.
- All primary flows are keyboard reachable (see `docs/INTERACTION-SPEC.md`).
