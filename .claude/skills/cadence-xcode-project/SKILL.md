---
name: cadence-xcode-project
description: Enforces the XcodeGen workflow for all Cadence project-structure changes. Every new Swift file addition requires a corresponding project.yml update — .pbxproj is never touched directly. Knows the full Cadence target structure, source group conventions, xcassets organization, and color/image asset Contents.json format. Asset catalogs are the only place color values are defined. Use this skill whenever adding Swift files, creating new groups, modifying the Xcode project structure, adding color or image assets, editing xcassets Contents.json, or making any change that touches the Cadence project spec file. Triggers on any question about project.yml, XcodeGen, .xcodeproj, .pbxproj, xcassets structure, asset Contents.json, color asset definitions, image set organization, target membership, source group layout, or project-structure governance in the Cadence codebase.
---

# Cadence Xcode Project — Structure Governance Skill

**Authoritative sources:** `docs/Cadence_SplashScreen_Spec.md` · `docs/Cadence_Design_Spec_v1.1.md` · `docs/Cadence_MVP_Spec.md`
**Project spec file:** `project.yml` (repo root — does not exist yet; this skill defines the required structure)
**Generated output:** `Cadence.xcodeproj` (never edit directly)

This skill owns all rules for Cadence project structure changes. XcodeGen is the only sanctioned workflow. Every structural change that begins in `project.yml` ends in a regenerated `.xcodeproj`. Everything else is a violation.

---

## 1. XcodeGen-Only Workflow

XcodeGen generates `Cadence.xcodeproj` from `project.yml`. The generated `.pbxproj` is a build artifact — not a source file.

**The workflow for every project-structure change:**

```
Edit project.yml → Run xcodegen generate → Commit project.yml + Cadence.xcodeproj
```

**Direct `.pbxproj` edits are prohibited.** XcodeGen regenerates it on every `xcodegen generate` run, overwriting any manual edits. Direct edits create irreproducible state that teammates cannot regenerate. They are not reviewable diffs and will cause merge conflicts that cannot be resolved without understanding the binary-like GUID structure.

**Why `project.yml` is the source of truth:**
It is human-readable, diffable, and entirely in version control. A reviewer can read a `project.yml` diff and understand exactly what changed without opening Xcode.

**The regeneration command:**
```bash
xcodegen generate --spec project.yml
```

Run this from the repo root after every `project.yml` edit. Commit both `project.yml` and the regenerated `Cadence.xcodeproj` together — never one without the other.

---

## 2. Required `project.yml` Structure

The Cadence project has **one application target** (`Cadence`). No test targets, extensions, or frameworks exist in the beta MVP scope. Do not add targets without explicit spec change.

```yaml
name: Cadence
options:
  deploymentTarget:
    iOS: "26.0"
  createIntermediateGroups: true
  groupSortPosition: bottom
settings:
  base:
    SWIFT_VERSION: 5.0
    IPHONEOS_DEPLOYMENT_TARGET: "26.0"
targets:
  Cadence:
    type: application
    platform: iOS
    deploymentTarget: "26.0"
    sources:
      - path: Cadence
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.cadence.tracker
        SWIFT_VERSION: 5.0
        INFOPLIST_FILE: Cadence/App/Info.plist
```

**Key options:**
- `createIntermediateGroups: true` — Xcode groups mirror the filesystem. Adding `Cadence/Views/Tracker/TrackerShell.swift` on disk creates the group hierarchy automatically. No manual group configuration needed for new files inside the `Cadence/` subtree.
- `groupSortPosition: bottom` — groups list after files within each level.

---

## 3. New Swift File Rule (Non-Negotiable)

**Every new Swift file must land in the correct filesystem path within the `Cadence/` source tree.** Because `createIntermediateGroups: true` is set, files added in the correct subdirectory under `Cadence/` are automatically picked up on the next `xcodegen generate` — no per-file entry in `project.yml` is needed.

**The rule in practice:**

1. Place the `.swift` file in the correct `Cadence/` subdirectory (see §4).
2. Run `xcodegen generate`.
3. Open `Cadence.xcodeproj` — the file now appears in the correct Xcode group.
4. Commit `project.yml` (unchanged if only a file was added), `Cadence.xcodeproj` (updated), and the new `.swift` file together.

**Anti-pattern — file added on disk without regenerating:**
The file exists on disk but is invisible to Xcode. It will not compile. It will not appear in the target. This is the most common source of "file not in target" bugs. Always regenerate after adding a file.

**Anti-pattern — file added via Xcode's "New File" dialog without regenerating from spec:**
Xcode writes the GUID directly into `.pbxproj`. The next `xcodegen generate` run will either overwrite the entry or conflict with it. Never add files through Xcode when XcodeGen manages the project — add the file on disk, then regenerate.

If `project.yml` needs explicit file exclusion or include patterns, use the `excludes` / `includes` fields under the source path:

```yaml
sources:
  - path: Cadence
    excludes:
      - "**/*.md"
      - "**/.DS_Store"
```

---

## 4. Target Structure and Source Group Conventions

**Single target:** `Cadence` (iOS application)

All Swift source files live under `Cadence/`. The group hierarchy below is derived from the Cadence spec documents and must be followed for all new files. Do not create ad hoc groups.

```
Cadence/
├── App/                        ← Entry point, AppCoordinator, Info.plist, ContentView
├── Views/
│   ├── Splash/                 ← SplashView.swift, CadenceMark.swift (Splash Spec v1.0)
│   ├── Auth/                   ← Auth flow, onboarding, role selection
│   ├── Tracker/                ← TrackerShell.swift, TrackerHomeView, CalendarView,
│   │                              ReportsView, TrackerSettingsView
│   ├── Partner/                ← PartnerShell.swift, PartnerHomeView, PartnerSettingsView
│   ├── Log/                    ← LogSheetView.swift (shared — owned by TrackerShell)
│   └── Shared/                 ← Reusable components: chips, cards, buttons
├── ViewModels/                 ← @Observable ViewModels, one per screen/flow
├── Models/                     ← SwiftData models, enums, value types, route enums
├── Services/                   ← SyncCoordinator, SupabaseClient, NWPathMonitor wrapper
└── Resources/
    ├── Colors.xcassets/        ← All color tokens — the ONLY place colors are defined
    └── Images.xcassets/        ← Brand marks, App Icon
```

**Target placement rules:**
- Tracker-role views → `Cadence/Views/Tracker/`
- Partner-role views → `Cadence/Views/Partner/`
- Views shared by both roles → `Cadence/Views/Shared/`
- `LogSheetView` lives in `Cadence/Views/Log/` — it is a Tracker-only surface presented by `TrackerShell`
- Route enums (`TrackerRoute`, `PartnerRoute`) → `Cadence/Models/`
- `AppSession`, session role enum → `Cadence/Models/`

**Do not** put Partner views in `Cadence/Views/Tracker/` or vice versa. Do not put ViewModels in `Cadence/Views/`. Do not create a flat `Cadence/Sources/` dumping ground.

---

## 5. Asset Catalog Governance

**Two asset catalogs, two purposes — never mix them:**

| Catalog | Path | Contents |
|---|---|---|
| `Colors.xcassets` | `Cadence/Resources/Colors.xcassets/` | All 11 color tokens — nothing else |
| `Images.xcassets` | `Cadence/Resources/Images.xcassets/` | Brand marks, App Icon assets — no colors |

### 5.1 Colors.xcassets — Complete Token Registry

These 11 color sets must exist. No others may be added without designer sign-off. No color set may be removed, renamed, or modified without explicit spec change.

| Color Set Name | Light Hex | Dark Hex | Usage |
|---|---|---|---|
| `CadenceBackground` | `#F5EFE8` | `#1C1410` | App-wide background |
| `CadenceCard` | `#FFFFFF` | `#2A1F18` | Card and sheet surfaces |
| `CadenceTerracotta` | `#C07050` | `#D4896A` | Primary accent: CTAs, active chips, active tab |
| `CadenceSage` | `#7A9B7A` | `#8FB08F` | Secondary accent: fertile window, insight cards |
| `CadenceSageLight` | `#EAF0EA` | `#1E2B1E` | Sage tinted surfaces |
| `CadenceTextPrimary` | `#1C1C1E` | `#F2EDE7` | All body copy and headings |
| `CadenceTextSecondary` | `#6C6C70` | `#98989D` | Subtitles, metadata, placeholders |
| `CadenceTextOnAccent` | `#FFFFFF` | `#FFFFFF` | Text on terracotta fills only |
| `CadenceBorder` | `#E0D8CF` | `#3A2E26` | 1pt card borders, chip outlines |
| `CadenceDestructive` | system red | system red | Account deletion, disconnect only |
| `CadenceMark` | `#C07050` | `#EDE4D8` | Splash screen mark — Splash Spec v1.0 |

**`CadenceDestructive`** uses the system red color asset — not a hex value. In its `Contents.json`, the color entry uses `"color-space": "srgb"` with no components; it instead references the system color: `"platform": "ios"` with `"reference": "systemRed"`. See §6.2 for the exact format.

**Flagged gap:** `CadencePrimary` is referenced in Design Spec §7 (paused sharing strip) but is NOT in the registry above. Do not create a `CadencePrimary.colorset` until the designer confirms the values. Flag this before implementing the paused strip.

### 5.2 Images.xcassets — Contents

| Asset Name | Type | Files | Purpose |
|---|---|---|---|
| `AppIcon` | `.appiconset` | Light, dark, tinted variants | App Icon (iOS 26 alternate appearances) |
| `cadence-mark-light` | `.imageset` | `cadence-mark-light.png` | Reference PNG for Bézier path tracing |
| `cadence-mark-dark` | `.imageset` | `cadence-mark-dark.png` | Reference PNG — dark variant |
| `cadence-mark-tinted` | `.imageset` | `cadence-mark-tinted.png` | Reference PNG — tinted variant |

Do not add color assets to `Images.xcassets`. Do not add image assets to `Colors.xcassets`.

---

## 6. Contents.json Format Patterns

### 6.1 Color Asset (`.colorset/Contents.json`)

The canonical format for a Cadence named color with light and dark appearance:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.910",
          "green" : "0.937",
          "red" : "0.961"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.063",
          "green" : "0.078",
          "red" : "0.110"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

The example above is `CadenceBackground` (light `#F5EFE8`, dark `#1C1410`).

**Structure rules:**
- The `colors` array always has exactly **two entries** for Cadence tokens: one for the "any" (light) appearance (no `appearances` key) and one for dark (with `"appearance": "luminosity"`, `"value": "dark"`).
- Color components are expressed as **decimal strings** in the `0.000`–`1.000` range (divide each hex byte by 255).
- `color-space` is always `"srgb"`.
- `idiom` is always `"universal"`.
- `info.author` is always `"xcode"`.
- `info.version` is always `1`.
- `alpha` is always `"1.000"` for all Cadence tokens.

**Hex-to-decimal conversion for all 11 tokens:**

| Token | Light (R/G/B) | Dark (R/G/B) |
|---|---|---|
| CadenceBackground | 0.961/0.937/0.910 | 0.110/0.078/0.063 |
| CadenceCard | 1.000/1.000/1.000 | 0.165/0.122/0.094 |
| CadenceTerracotta | 0.753/0.439/0.314 | 0.831/0.537/0.416 |
| CadenceSage | 0.478/0.608/0.478 | 0.561/0.690/0.561 |
| CadenceSageLight | 0.918/0.941/0.918 | 0.118/0.169/0.118 |
| CadenceTextPrimary | 0.110/0.110/0.118 | 0.949/0.929/0.906 |
| CadenceTextSecondary | 0.424/0.424/0.439 | 0.596/0.596/0.616 |
| CadenceTextOnAccent | 1.000/1.000/1.000 | 1.000/1.000/1.000 |
| CadenceBorder | 0.878/0.847/0.812 | 0.227/0.180/0.149 |
| CadenceMark | 0.753/0.439/0.314 | 0.929/0.894/0.847 |

**`CadenceDestructive`** uses a system color reference — not components. Its `Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemRed"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

### 6.2 Image Asset (`.imageset/Contents.json`)

The canonical format for a Cadence reference image (single PNG, universal, 1x):

```json
{
  "images" : [
    {
      "filename" : "cadence-mark-light.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

The locked brand mark PNGs are single-scale reference assets. Only the `1x` slot has a `filename`. The `2x` and `3x` slots are present but empty — this is correct for reference-only assets not used in rendered UI.

**Structure rules:**
- `idiom` is `"universal"` for all Cadence image assets.
- `scale` values are `"1x"`, `"2x"`, `"3x"`.
- Only slots with actual image files include the `"filename"` key.
- `info.author` is `"xcode"`, `info.version` is `1`.

### 6.3 App Icon Asset (`.appiconset/Contents.json`)

iOS 26 supports light, dark, and tinted App Icon variants. The `AppIcon.appiconset` uses the appearances array on the image entries (same pattern as color assets):

```json
{
  "images" : [
    {
      "filename" : "cadence-mark-light.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "cadence-mark-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "cadence-mark-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

---

## 7. Color Source-of-Truth Rule

**Asset catalogs are the only place color values are defined.** This rule is absolute.

The Design Spec §3 states: "All colors are defined as named Color assets in xcassets with explicit light and dark mode values. No hardcoded hex values in Swift source files."

In Swift source, colors are referenced exclusively via:
```swift
Color("CadenceTerracotta")          // recommended — explicit asset name
Color("CadenceBackground")
```

**Prohibited — reject immediately:**

```swift
// ❌ Hardcoded hex in Swift
Color(hex: "#C07050")
Color(red: 0.753, green: 0.439, blue: 0.314)
UIColor(red: 0.753, green: 0.439, blue: 0.314, alpha: 1.0)

// ❌ System colors used where a Cadence token exists
Color.orange       // use CadenceTerracotta
Color.green        // use CadenceSage
Color.primary      // use CadenceTextPrimary (except .primary for wordmark per Splash Spec)
Color.secondary    // use CadenceTextSecondary

// ❌ Hex strings in asset Contents.json components field
"red": "0xC0"      // use decimal: "red": "0.753"
```

The **only** sanctioned raw hex in Swift source is `#000000` for the Sign in with Apple button background — an Apple branding requirement. Every other color, without exception, must reference a named color asset.

---

## 8. Anti-Pattern Reference Table

| Anti-pattern | Rule violated | Section |
|---|---|---|
| Editing `.pbxproj` directly | XcodeGen-only workflow | §1 |
| Adding a Swift file without running `xcodegen generate` | New Swift file rule | §3 |
| Adding files via Xcode "New File" without regenerating from spec | XcodeGen-only workflow | §3 |
| Committing `Cadence.xcodeproj` without a matching `project.yml` change | Spec-project atomicity | §1 |
| Placing a Tracker view in `Views/Partner/` or vice versa | Target structure | §4 |
| Placing a ViewModel inside `Views/` | Source group conventions | §4 |
| Adding color assets to `Images.xcassets` | Asset catalog separation | §5 |
| Adding image assets to `Colors.xcassets` | Asset catalog separation | §5 |
| Creating a new color set not in the token registry | Designer sign-off required | §5.1 |
| Creating `CadencePrimary.colorset` without designer confirmation | Flagged gap | §5.1 |
| Using `"red": "0xC0"` hex strings in Contents.json | Decimal-only components | §6.1 |
| Contents.json with only one color entry (missing dark) | Two-entry requirement | §6.1 |
| Hardcoded hex value in Swift source for a Cadence token | Color source-of-truth rule | §7 |
| `Color(red:green:blue:)` in Swift for a Cadence token | Color source-of-truth rule | §7 |
| `Color.primary` used for body text | Wrong system color | §7 |
| Adding a second application target without spec change | Single-target rule | §2 |

---

## 9. Project-Change Checklist

Before committing any project-structure or asset change:

- [ ] `project.yml` is the only file edited to change project structure — `.pbxproj` not touched directly.
- [ ] `xcodegen generate` was run after every `project.yml` edit.
- [ ] New Swift file is in the correct `Cadence/` subdirectory per the group conventions in §4.
- [ ] `Cadence.xcodeproj` is committed alongside the new/modified `.swift` files.
- [ ] New color asset is listed in the token registry (§5.1) — no ad hoc additions.
- [ ] New color asset's `Contents.json` has exactly two color entries (any + dark).
- [ ] Color components are decimal strings (`"0.753"`, not `"0xC0"`).
- [ ] No hex color values exist in Swift source for the added/modified views.
- [ ] No color assets placed in `Images.xcassets`; no image assets in `Colors.xcassets`.
- [ ] `CadencePrimary` gap flagged if implementing the paused sharing strip.
- [ ] App Icon variants are in `AppIcon.appiconset` within `Images.xcassets`, not as standalone imagesets.

If any item cannot be checked off, stop and resolve it before opening a PR.
