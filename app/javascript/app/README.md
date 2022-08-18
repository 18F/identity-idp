# App Scripts

This folder contains legacy JavaScript which hasn't yet been migrated to the [`packages`-based](../packages) implementation standard. It exists from a time when all JavaScript was shipped in a single, monolithic application bundle. To better support scalability, it is now recommended to split JavaScript to smaller [`packs`](../packs) which are loaded in service of individual features, components, or pages.

Avoid adding new code to this folder. Whenever possible, updates to existing files should attempt to migrate those files to a `package` implementation.
