# Packages

Packages are independent JavaScript libraries. As much as possible, their behaviors should be reusable and make no assumptions about particular application pages or configuration. Instead, they should be initialized by a [`pack`](../packs) which provides relevant configuration and page element references.

A package should behave much like any other third-party [npm package](https://www.npmjs.com/), where each folder in this directory represents a single package. These packages are managed using [npm workspaces](https://docs.npmjs.com/cli/using-npm/workspaces). Refer to [Front-end Architecture documentation on npm Workspaces](https://github.com/18F/identity-idp/blob/main/docs/frontend.md#npm-workspaces) for more information.
