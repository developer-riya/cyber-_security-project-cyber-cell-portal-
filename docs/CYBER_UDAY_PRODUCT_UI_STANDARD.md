# Cyber Uday Product UI Standard

This document defines the visual and interaction standard for every future Cyber Uday screen. It is a product rule, not a screen-specific redesign brief.

Cyber Uday should feel like one mature, trustworthy product across Android, iOS, mobile web, tablet, and desktop web. The product may grow new capabilities, but each capability must still look and behave as part of the same system.

## Product Philosophy

Cyber Uday is a calm digital bodyguard. The interface should communicate trust, protection, clarity, and technical maturity. Content and actions should be easy to scan, understand, and complete.

Use the product discipline of mature consumer and technology platforms as inspiration for consistency, hierarchy, and reliability. Do not copy their branding, colors, layouts, logos, or proprietary UI patterns.

## Visual Principles

1. Use a neutral-first visual system.
2. Keep brand colors limited and purposeful.
3. Use semantic colors only when their meaning requires them.
4. Establish a strong typography hierarchy before adding decoration.
5. Use the shared spacing scale consistently.
6. Use shared card variants instead of one-off card treatments.
7. Use shared button variants for all actions.
8. Keep navigation patterns consistent across products and breakpoints.
9. Keep responsive behavior predictable across phone, tablet, and desktop.
10. Treat accessibility as a default requirement.
11. Use subtle, short, purposeful motion.
12. Prefer content-first layouts with clear primary actions.
13. Remove decoration that does not improve comprehension or confidence.
14. Do not add random gradients.
15. Do not create rainbow feature cards or assign arbitrary colors to features.
16. Do not use excessive glassmorphism, blur, or shadow.
17. Do not use cyberpunk or hacker visual clichés.
18. Do not give individual screens unrelated design languages.

## Color Standard

Use the semantic tokens in `lib/core/theme/cyber_tokens.dart` and the shared themes in `lib/core/theme/cyber_theme.dart`.

Primary surfaces and content should use:

- White and off-white for backgrounds and surfaces.
- Black and near-black for primary text and important actions.
- Neutral gray for secondary text, borders, dividers, and disabled states.

Semantic colors are reserved for meaning:

- Green means safe, successful, verified, or completed.
- Amber means warning or attention required.
- Red means danger, emergency, or critical threat.

The brand accent is restrained. A feature must not receive its own arbitrary color merely to make it visually distinct.

## Typography Standard

Use the shared typography tokens in `CyberTypography`. Typography should create hierarchy through size, weight, and spacing rather than decorative effects or excessive uppercase text.

Text must remain readable and localization-friendly. Avoid fixed-width assumptions, clipped labels, and letter-spacing that makes translated text harder to read.

## Spacing and Layout Standard

Use `CyberSpacing`, `CyberRadius`, `CyberElevation`, `CyberDimensions`, and `CyberBreakpoints` for layout decisions. Do not scatter arbitrary padding, radius, control height, or breakpoint values through new screens.

Layouts should have a clear content width, generous but intentional whitespace, and stable dimensions for controls and repeated items. Content must remain usable when text expands.

## Card Standard

Cards must have:

- A shared radius and predictable padding.
- Controlled elevation or a restrained border, not both by default.
- Clear title, supporting content, and action hierarchy.
- Readable typography and accessible contrast.

Use `CyberCard` variants for standard, elevated, action, emergency, status, compact, and list-row content. A variant may communicate meaning, but it must still look like part of the Cyber Uday system.

## Button and Input Standard

Use `CyberButton` for primary, secondary, tertiary, danger, and success actions. Use `CyberIconButton` for icon-only actions and provide a meaningful tooltip or semantic label.

Use the shared input components for text, search, OTP, dropdown, and multiline flows. Every input needs a visible or semantic label, clear focus state, validation state, and disabled state where applicable.

Emergency and danger styling is reserved for genuine emergency or destructive actions. It must never be used as a decorative accent.

## Navigation Standard

Mobile navigation, desktop navigation, side navigation, and top navigation must share the same color, typography, icon, spacing, focus, and selected-state language. Navigation should make the current location clear without relying on color alone.

Do not introduce a new navigation pattern for a single screen. Extend the existing navigation system when a new destination is required.

## Motion Standard

Motion should be subtle, short, and purposeful. Use it to communicate state changes, hierarchy, and continuity. Respect reduced-motion settings and ensure that no important information is conveyed only through animation.

Avoid particles, flashing, excessive glow, cyberpunk animations, decorative 3D effects, rotating logos, and continuous motion that competes with content.

## Responsive Standard

Every future screen must work as one coherent design across:

- Android phones and iPhones.
- Small and large mobile web viewports.
- Tablets.
- Desktop web.

Do not create unrelated mobile and desktop products. Prefer shared composition with responsive constraints, wrapping, adaptive columns, and content-aware spacing.

## Accessibility Standard

All new UI must provide sufficient contrast, readable text, touch-friendly controls, keyboard focus on web, semantic labels for icon-only actions, and screen-reader-friendly structure. Text must scale without overlap or clipping.

## Multilingual Standard

Cyber Uday is intended for users across India. New UI must accommodate English, Hindi, Marathi, and additional Indian languages later.

- Keep user-facing strings in localization resources rather than hard-coding them into layout logic.
- Allow for text expansion and different word lengths.
- Avoid fixed-width labels and assumptions about line count.
- Use components that preserve hierarchy when translated text wraps.
- Keep icons supportive; do not make color or icon shape the only carrier of meaning.

## Component Reuse Rule

Before creating a new UI component, ask:

> Does this already belong in the Cyber Uday Design System?

If yes, reuse the existing component. If no, extend the shared design system in `lib/core/` before adding a screen-specific implementation. New tokens should be semantic and reusable, never arbitrary names such as `blueCard` or `specialPadding`.

## Review Checklist

Before merging a future screen, confirm:

- It uses shared tokens and components.
- It follows the neutral-first and semantic-color rules.
- It works at phone, tablet, and desktop widths.
- It supports localization-friendly text growth.
- It has accessible labels, contrast, focus, and touch targets.
- Its motion is purposeful and reduced-motion aware.
- It does not introduce a screen-specific visual language.
