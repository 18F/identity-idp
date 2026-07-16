# Login.gov redesign


We're working on a Login.gov redesign, component by component.

Use the tokens in _ads.scss as the ground truth for the components.

As you design components, put things that would be used across multiple components in _ads.scss and place the tokens in the component file otherwise.

**Strict constraints (non-negotiable):** minimum code — aggressively delete dead markup/CSS/helpers/wrappers on every change; net line count must trend down or stay flat; no verbose markup or leftover legacy scaffolding. **No backend changes** — never modify controllers, forms, models, routes, services, jobs, migrations, or Ruby request/validation logic unless the user explicitly asks. See `.cursor/rules/ads-page-reskin.mdc`.
