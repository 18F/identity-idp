# Front end architecture
## CSS
- The front end will use the Web Design Standard's components, imported through ruby, adding extra functionality that's missing.
- The front end utilizes single-purposed, reusable utility classes (atomic CSS) to build new UI. Utility classes should do one thing and do it well, they should be simple and obvious to use, and they should operate independently.
  - If you find yourself repeating HTML elements with the same set of atomic classes, consider refactoring UI into its own template (partial) to be included across views.
- Will update CSS libraries (such as the WDS) on a bi-monthly basis or more immediately if a feature is added that's needed.
- Will use `js-`* prefixed classes for JavaScript hooks.
- Will use `test-`* prefixed classes for testing hooks, mainly integration testing.
- Uses the [18f linting config](https://raw.githubusercontent.com/18F/frontend/18f-pages-staging/.scss-lint.yml) for scss linting.
- Use `scss-lint` which runs on the latest PR commits.
- CodeClimate will notify on a PR on Github if there are any linting infractions.
- Always default to semantic HTML.

## JavaScript
- The site should work without JavaScript because there is no need for complex user interactions that would use JS.
- The site should not require jQuery.
- Should use the AirBnB linter configuration for JavaScript.
- CodeClimate will notify on a PR on Github if there are any linting infractions.
- All front end dependencies should be expressed in `package.json`.
- Many of the dependencies for the app are in the `Gemfile` since it is a Rails app.
- Front end dependencies will be upgraded when a vurlnability is found.
- Just one JavaScript file will be bundled up and sent to the client

### Testing
- Integration tests and unit tests should always be running without failure.
- Tests should be added/updated with new functionality and when features are changed.
- Attempt to unit test data related JS; functional/integration tests are fine for DOM related code
- If you’re having problems with you functional testing framework being consistent (random failures, fragile tests that always break) consider not adding new tests and disabling broken tests after ~10 minutes of attempting to fix them to ensure the team can move quickly and without too much frustration.

## Devices
- Strive to support all browsers with > 1% usage
- The site should work well for users across all device sizes
- Accessibility HTML code sniffer should be hooked into build process
