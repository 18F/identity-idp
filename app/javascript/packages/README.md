# Packages

Packages are independent JavaScript libraries. As much as possible, their behaviors should be reusable and make no assumptions about particular application pages or configuration. Instead, they should be initialized by a [`pack`](../packs) which provides relevant configuration and page element references.

A package should behave much like any other third-party [NPM package](https://www.npmjs.com/), where each folder in this directory represents a single package. These packages are managed using [Yarn workspaces](https://classic.yarnpkg.com/lang/en/docs/workspaces/).

Each package should include a `package.json` with at least `name`, `version`, and `private` fields:

- Name should start with `@18f/identity-` and end with the folder name
- Version should be fixed to `1.0.0`
- Packages should be private, since they are not published
- Any `devDependencies` should be defined in the root project directory, not in a package
- Define `dependencies` for any third-party libraries used in a package
  - It is not necessary to define `dependencies` for other sibling packages

**Example:**

_packages/analytics/package.json_

```json
{
  "name": "@18f/identity-analytics",
  "version": "1.0.0",
  "private": true
}
```
