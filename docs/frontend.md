# Front-end Architecture

While the Login.gov application is architected as a Ruby on Rails project and most of its pages are
fully rendered by the backend server, the front end is set up to use modern best-practices to suit
the needs of interactivity and consistency in the user experience, and to ensure a maintainable and
convenient developer experience.

As a high-level overview, the front end consists of:

- [Propshaft](https://github.com/rails/propshaft) is used as an asset pipeline library for Ruby on
  Rails, in combination with [cssbundling-rails](https://github.com/rails/cssbundling-rails) and
  [jsbundling-rails](https://github.com/rails/jsbundling-rails) for compiling stylesheets and
  scripts.
- JavaScript is written as [TypeScript](https://www.typescriptlang.org/), bundled using [Webpack](https://webpack.js.org/)
  with syntax transformation applied by [Babel](https://babeljs.io/).
   - For highly-interactive pages, we use [React](https://react.dev/)
   - For all other JavaScript interaction, we use native [web components](https://developer.mozilla.org/en-US/docs/Web/API/Web_components)
     (custom elements)
- Stylesheets are written as [Sass](https://sass-lang.com/), and builds upon the [Login.gov Design System](https://github.com/18F/identity-design-system),
  which in turn builds upon the [U.S. Web Design System (USWDS)](https://designsystem.digital.gov/).
- HTML reuse is facilitated by the [ViewComponent](https://viewcomponent.org/) gem.

The general folder structure for front-end assets includes:

- `app/`
  - `assets/`
    - `builds/`: Source location for compiled stylesheets used by Propshaft in asset compilation
    - `fonts/`: Source font assets
    - `images/`: Source image assets
    - `stylesheets/`: Source Sass files
  - [`components/`][components-readme]: ViewComponent implementations
  - `javascript/`
    - [`packages/`][packages-readme]: JavaScript workspace NPM packages
    - [`packs/`][packs-readme]: JavaScript entrypoints referenced by pages
- `public/`
  - `assets/`: Compiled images, fonts, and stylesheets
  - `packs/`: Compiled JavaScript

[components-readme]: ../app/components/README.md
[packages-readme]: ../app/javascript/packages/README.md
[packs-readme]: ../app/javascript/packs/README.md

## CSS + HTML

### At a Glance

- Leverages components and utilities from the [Login.gov Design System](https://github.com/18f/identity-design-system),
  which is based on the [U.S. Web Design System](https://designsystem.digital.gov/).
- Uses [Sass](https://sass-lang.com/) as the CSS preprocessor and [Stylelint](https://stylelint.io/)
  to keep files tidy.
- Uses well-structured, accessible, semantic HTML.

### Design System

To the extent possible, use design system components and utilities when implementing designs.

**Components** are simple and consistent solutions to common user interface needs, like form fields,
buttons, and icons. See the [Components section](#components) below for more information.

**Utilities** are CSS classes which allow you to add consistent styling to an HTML element, such as
margins or borders.

- [U.S. Web Design System utilities](https://designsystem.digital.gov/utilities/)

### CSS Build Tooling

Stylesheets are compiled from Sass source files using our [`@18f/identity-build-sass` NPM package](../app/javascript/packages/build-sass/README.md)
`build-sass` command-line utility.

`@18f/identity-build-sass` is a wrapper of the official Sass [`sass-embedded` NPM package](https://www.npmjs.com/package/sass-embedded),
with a few additional features:

- Minifies stylesheets in production environments.
- Downgrades stylesheets to use browser vendor prefixes where necessary.
- Adds load paths for the [Login.gov Design System](https://github.com/18f/identity-design-system)
  and [U.S. Web Design System](https://designsystem.digital.gov/).

Sass source files are automatically compiled from:

- `app/assets/stylesheets/`: Application-wide stylesheets to be included in every page.
- `app/components/`: Stylesheets which are loaded automatically whenever the corresponding
  ViewComponent component implementation is used in a page.

Compiled files are output to the `app/assets/builds/` directory, which is where [Propshaft](https://github.com/rails/propshaft)
looks for assets referenced by asset URL helpers like `stylesheet_path` and others.

In deployed environments, we rely on Propshaft to append a [fingerprint](https://en.wikipedia.org/wiki/Fingerprint_(computing))
suffix to invalidate caches for previous versions of the stylesheet.

The [`cssbundling-rails` gem](https://github.com/rails/cssbundling-rails) is a dependency of the
project, which enhances `rake assets:precompile` to invoke `yarn build:css` as part of
[assets precompilation](https://guides.rubyonrails.org/asset_pipeline.html#precompiling-assets)
during application deployment.

## JavaScript

### At a Glance

- All new code is expected to be written using [TypeScript](https://www.typescriptlang.org/) (`.ts` or `.tsx` file extension)
- The site should be functional even when JavaScript is disabled, with a few specific exceptions (identity proofing)
- The code follows [TTS JavaScript standards](https://engineering.18f.gov/javascript/), using a [custom ESLint configuration](https://github.com/18F/identity-idp/tree/main/app/javascript/packages/eslint-plugin)
- Code styling is formatted automatically using [Prettier](https://prettier.io/)
- Packages are managed with [Yarn](https://classic.yarnpkg.com/), organized using [Yarn workspaces](https://classic.yarnpkg.com/en/docs/workspaces/)
- JavaScript is transpiled, bundled, and minified via [Webpack](https://webpack.js.org/) and [Babel](https://babeljs.io/)

### Naming Conventions

- Files within `app/javascript` should be named as kebab-case, e.g. `./path-to/my-javascript.ts`.
- Variables and functions (excluding React components) should be named as camelCase, e.g. `const myFavoriteNumber = 1;`.
   - Only the first letter of an abbreviation should be capitalized, e.g. `const userId = 10;`.
   - All letters of an acronym should be capitalized, e.g. `const siteURL = 'https://example.com';`.
- Classes, React components, and TypeScript types should be named as PascalCase (upper camel case), e.g. `class MyCustomElement {}`.
- Constants should be named as SCREAMING_SNAKE_CASE, e.g. `const MEANING_OF_LIFE = 42;`.
- TypeScript enums should be named as PascalCase with SCREAMING_SNAKE_CASE members, e.g. `enum Color { RED = '#f00'; }`.

Related: [Component Naming Conventions](#naming)

### Prettier

[Prettier](https://prettier.io/) is an opinionated code formatter which simplifies adherence to
JavaScript style standards, both for the developer and for the reviewer. As a developer, it can
eliminate the effort involved with applying correct formatting. As a reviewer, it avoids most
debates over code style, since there is a consistent style being enforced through the adopted
tooling.

Prettier is integrated with [the project's linting setup](#eslint). Most issues can be resolved
automatically by running `yarn run lint --fix`. You may also consider one of the
[available editor integrations](https://prettier.io/docs/en/editors.html), which can simplify your
workflow to apply formatting automatically on save.

### Yarn Workspaces

[Workspaces](https://classic.yarnpkg.com/en/docs/workspaces/) allow a developer to create and
organize code which is used just like any other NPM package, but which doesn't require the overhead
involved in publishing those modules and keeping versions in sync across multiple repositories. We
use Yarn workspaces to keep JavaScript code organized, reusable, and to encourage good coding
practices in abstractions.

In practice:

- All folders within `app/javascript/packages` are treated as workspace packages.
- Each package should have its own `package.json` that includes...
  - ...a `name` starting with `@18f/identity-` and ending with the name of the package folder.
  - ...a [`private`](https://docs.npmjs.com/files/package.json#private) value indicating whether the
    package is intended to be published to NPM.
  - ...a value for the `version` field, since it is required. The value value can be anything, and
    `"1.0.0"` is a good default.
  - ...a `sideEffects` value listing files containing any side effects, used for [Webpack's Tree Shaking optimization](https://webpack.js.org/guides/tree-shaking/).
- The package should be importable by its bare name, either with an `index.ts` or equivalent
  [package entrypoints](https://nodejs.org/api/packages.html#package-entry-points)

As with any public NPM package, a workspace package should ideally be reusable and avoid direct
references to page elements. In order to integrate a package within a particular page, you should
either reference it within [a ViewComponent component's accompanying script](https://github.com/18F/identity-idp/blob/main/app/components/README.md),
or by creating a new `app/javascript/packs` file to be loaded on a page.

Because Yarn will alias workspace packages using symlinks, you can reference a package using the
name you assigned using the guidelines above for `package.json` `name` field (for example,
`import { Button } from '@18f/identity-components';`).

### Dependencies

While the project is not a Node.js application or library, the distinction between `dependencies`
and `devDependencies` is important due to how assets are precompiled in deployed environments.
During a deployment, dependencies are installed using [the `--production` flag](https://classic.yarnpkg.com/lang/en/docs/cli/install/#toc-yarn-install-production-true-false),
meaning that all dependencies which are required to build the project must be defined as
`dependencies`, not as `devDependencies`.

`devDependencies` should be reserved for dependencies which are not required to compile application
assets, such as testing-related libraries or [DefinitelyTyped](https://www.typescriptlang.org/dt/)
TypeScript declaration packages. When possible, it is still useful to define `devDependencies` to
improve the performance of application asset compilation.

When installing new dependencies, consider whether the dependency is relevant for an individual
workspace package, or for the entire project. By default, Yarn will warn when trying to install a
dependency in the root package, since dependencies should typically be installed for a specific
workspace.

To install a dependency to a workspace:

```bash
yarn workspace @18f/identity-build-sass add sass-embedded
```

To install a dependency to the project:

```bash
# Note the `-W` flag
yarn add -W webpack
```

As much as possible, try to use the same version of a dependency when it is used across multiple
workspace packages. Otherwise, it can inflate the size of the compiled bundles and have a negative
performance impact on users.

We use [`yarn-deduplicate`](https://github.com/scinos/yarn-deduplicate)
to deduplicate resolved package versions within the Yarn lockfile, and enforce it with
the `make lint_yarn_lock` check.

### Localization

See [`@18f/identity-i18n` package documentation](../app/javascript/packages/i18n/README.md).

### Analytics

See [`@18f/identity-analytics` package documentation][analytics_package] for code examples detailing
how to track an event in JavaScript.

Any event logged from the frontend must be added to the `ALLOWED_EVENTS` allowlist in [`FrontendLogController`][frontend_log_controller.rb].
This is an allowlist of events defined in [AnalyticsEvents][analytics_events.rb] which are allowed
to be logged from the frontend. All properties will be passed automatically to the event from the
frontend as long as they are defined in the method argument signature.

There may be some situations where you need to append a value known by the server to an event logged
in the frontend, such as an A/B test bucket descriptor. In these scenarios, you have a few options:

1. Add the value to the page markup, such as through an [HTML `data-` attribute][data_attributes],
and reference that attribute in JavaScript.
2. Implement a mixin to intercept and override the default behavior of an analytics event, such as
how [`Idv::AnalyticsEventEnhancer`][analytics_events_enhancer.rb] is implemented.

[analytics_package]: ../app/javascript/packages/analytics/README.md
[frontend_log_controller.rb]: https://github.com/18F/identity-idp/blob/main/app/controllers/frontend_log_controller.rb
[analytics_events.rb]: https://github.com/18F/identity-idp/blob/main/app/services/analytics_events.rb
[data_attributes]: https://developer.mozilla.org/en-US/docs/Learn/HTML/Howto/Use_data_attributes
[analytics_events_enhancer.rb]: https://github.com/18F/identity-idp/blob/main/app/services/idv/analytics_events_enhancer.rb

### JavaScript Build Tooling

JavaScript is bundled using [Webpack](https://webpack.js.org/) with syntax transformation applied by
[Babel](https://babeljs.io/).

Webpack is configured to look for entrypoints in:

- `app/javascript/packs/`: JavaScript bundles that are loaded in Ruby on Rails view files using the
  `javascript_packs_tag_once` script helper.
- `app/components/`: JavaScript bundles which are loaded automatically whenever the corresponding
  ViewComponent component implementation is used in a page.

Compiled files are output to the `public/packs/` directory, along with a manifest file. The manifest
file is used by the Ruby on Rails backend to determine all of the assets associated with a given
pack to be included when the script is referenced:

- The exact file name of the compiled script, which may include a [fingerprint](https://en.wikipedia.org/wiki/Fingerprint_(computing))
  suffix to invalidate caches for previous versions of the script in deployed environments.
- A list of images and other assets referenced in a script using [`@18f/identity-assets` package](../app/javascript/packages/assets/README.md)
  utilities.
- A reference to additional JavaScript file for each locale containing translations, if the script
  uses [`@18f/identity-i18n` package](../app/javascript/packages/i18n/README.md)
  translation functions.
- SHA256 checksums of compiled scripts, used for [subresource integrity attributes](https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity).

As an example, see [the manifest file for current production JavaScript assets](https://secure.login.gov/packs/manifest.json).

The manifest is generated using [WebpackManifestPlugin](https://github.com/shellscape/webpack-manifest-plugin),
enhanced with custom Webpack plugins:

- [`RailsAssetsWebpackPlugin`][rails-assets-webpack-plugin-readme]: Detects calls to `getAssetPath`
  to enhance the manifest to include the set of assets referenced by a script bundle.
- [`RailsI18nWebpackPlugin`][rails-i18n-webpack-plugin-readme]: Detects calls to `t` translation
  function to generate new script files for every supported locale containing translations data for
  keys referenced by a script bundle, enhancing the manifest to add those new script files as
  additional assets of the script.

The JavaScript manifest is parsed by the [`AssetSources` class](../lib/asset_sources.rb) when the
[`render_javascript_pack_once_tags` script helper method](../app/helpers/script_helper.rb) is called
in the application's view layout.

The [`jsbundling-rails` gem](https://github.com/rails/jsbundling-rails) is a dependency of the
project, which enhances `rake assets:precompile` to invoke `yarn build` as part of [assets precompilation](https://guides.rubyonrails.org/asset_pipeline.html#precompiling-assets)
during application deployment.

[rails-assets-webpack-plugin-readme]: ../app/javascript/packages/assets/README.md
[rails-i18n-webpack-plugin-readme]: ../app/javascript/packages/rails-i18n-webpack-plugin/README.md

## Image Assets

When possible, use SVG format for images, as these render at higher quality and with a smaller file
size. Most images in the project are either illustrations or icons, which are ideal for vector image
formats (SVG).

There are few exceptions to this, such as [images used in emails][email-images] needing to be in a
raster format (PNG) due to lack of SVG support in popular email clients. Logos for relying parties
may also be rendered in formats other than SVG, since these are provided to us by partners.

Image assets saved in source control should be optimized using a lossless image optimizer before
being committed, to ensure they're served to users at the lowest possible file size. This is
[enforced automatically for SVG images][lint-optimized-assets], but must be done manually for other
image types. Consider using a tool like [Squoosh][squoosh] (web) or [ImageOptim][image-optim]
(macOS) for these other image types.

Since images, GIFs, and videos are artifacts authored in other tools, there is no need to keep
multiple variants of an asset (e.g., SVG and PNG) in the repository if they are not in use.

[email-images]: https://github.com/18F/identity-idp/tree/main/app/assets/images/email
[lint-optimized-assets]: https://github.com/18F/identity-idp/blob/a1b4c5687739c080cb1d8c66db01956c87b63792/Makefile#L250-L251
[squoosh]: https://squoosh.app/
[imageoptim]: https://imageoptim.com/mac

## Components

### Design System

Any of the [U.S. Web Design system components](https://designsystem.digital.gov/components/overview/)
are available to use. Through the Login.gov Design System, we have customized some of these
components to suit our needs.

### Implementations

We use a mixture of complementary component implementation approaches to support both server-side
and client-side rendering.

#### View Components

The [ViewComponent gem](https://viewcomponent.org/) is a framework for creating reusable, testable,
and independent view components, rendered server-side.

For more information, refer to the [components `README.md`](../app/components/README.md).

To preview components and their available options, we use [Lookbook](https://lookbook.build/) to
generate a navigable index of our available components. These previews are available at the [`/components/` route](http://localhost:3000/components/)
in local development, review applications, and in the `dev` environment. When adding a new component
or an option to an existing component, you should also make this component or option available in
Lookbook previews, found under [`spec/components/previews`](https://github.com/18F/identity-idp/tree/main/spec/components/previews).
Refer to [Lookbook's _Previews Overview_ documentation](https://lookbook.build/guide/previews) for
more information on how to author Lookbook previews.

#### React

For non-trivial client-side interactivity, we use [React](https://reactjs.org/) to build and combine
JavaScript components for stateful applications.

* Components should be implemented as [function components](https://react.dev/learn/your-first-component),
using [hooks](https://react.dev/reference/react) to manage the component lifecycle.
* Application state is managed using [context](https://react.dev/learn/passing-data-deeply-with-context),
where domain-specific state is passed from a context provider to a child component.
* Client-side routing is not a concern that you should typically encounter, since the project is not
a single-page application. However, the [`@18f/identity-form-steps` package](https://github.com/18F/identity-idp/tree/main/app/javascript/packages/form-steps)
is available if you need to implement a series of steps within a page.

#### Custom Elements

For simple client-side interactivity tied to singular components (React or ViewComponent), we use
[native custom elements](https://developer.mozilla.org/en-US/docs/Web/Web_Components/Using_custom_elements).

Custom elements provide several advantages in that they...

- can be initialized from any markup renderer, supporting both server-side (ViewComponent) and
  client-side (React) component implementations
- have no dependencies, limiting overall page size in the critical path
- are portable and avoid vendor lock-in

### Conventions

#### Naming

Each component should have a name that is used consistently in its implementation and which
describes its purpose. This should be reflected in file names and the code itself.

- ViewComponent classes should be named `[ExampleName]Component`
- ViewComponent classes should be defined in `app/components/[example_name]_component.rb`
- ViewComponent stylesheets should be named `app/components/[example_name].scss`
- ViewComponent scripts should be named `app/components/[example_name].ts`
- Stylesheet selectors should use `[example-name]` as the ["block name" in BEM](https://en.bem.info/methodology/naming-convention/#two-dashes-style)
- React components should be named `<[ExampleName] />`
- React component files should be named `app/javascript/packages/[example-name]/[example-name].tsx`
- Web components should be named `[ExampleName]Element`
- Web components files should be named `app/javascript/packages/[example-name]/[example-name]-element.ts`

For example, consider a **Password Input** component:

- A ViewComponent implementation would be named `PasswordInputComponent`
- A ViewComponent classes would be defined in `app/components/password_input_component.rb`
- A ViewComponent stylesheet would be named `app/components/password_input_component.scss`
- A ViewComponent script would be named `app/components/password_input_component.ts`
- A stylesheet selector would be named `.password-input`, with child elements prefixed as `.password-input__`
- A React component would be named `<PasswordInput />`
- A React component file would be named `app/javascript/packages/password-input/password-input.tsx`
- A web component would be named `PasswordInputElement`
- A web components file would be named `app/javascript/packages/password-input/password-input-element.ts`

## Testing

### Stylelint

Login.gov publishes and uses
[our own custom Stylelint configuration](https://www.npmjs.com/package/@18f/identity-stylelint-config),
which is based on [TTS engineering best-practices](https://engineering.18f.gov/css/) and includes recommended Sass rules, applies [Prettier](https://prettier.io/) formatting, and
enforces
[BEM-style class naming conventions](https://en.bem.info/methodology/naming-convention/#two-dashes-style).

It may be useful to consider installing a
[Prettier editor integration](https://prettier.io/docs/en/editors.html) to automatically format
files on save. Similarly, a
[Stylelint editor integration](https://stylelint.io/user-guide/integrations/editor) can help
identify issues in your code as you write.

### Mocha

[Mocha](https://mochajs.org/) is used as a test runner for JavaScript code.

JavaScript tests include a combination of unit tests and integration tests, with a heavier emphasis
on integration tests since the bulk of our front-end code is in service of user interactivity.

To simplify common test behaviors and encourage best practices, we make extensive use of the
[Testing Library](https://testing-library.com/) suite of testing libraries, which can be used to
render and query [basic DOM elements](https://testing-library.com/docs/dom-testing-library/intro) as
well as advanced [React components](https://testing-library.com/docs/react-testing-library/intro).
Their APIs are designed in a way to [accurately simulate real user behavior](https://testing-library.com/docs/user-event/intro)
and support [querying by accessible semantics](https://testing-library.com/docs/queries/byrole).

To run all test specs:

```
yarn test
```

To run a single test file:

```
yarn mocha app/javascript/packages/analytics/index.spec.ts
```

You can also pass any [Mocha command-line arguments](https://mochajs.org/#command-line-usage).

For example, to watch a file and rerun tests after any change:

```
yarn mocha app/javascript/packages/analytics/index.spec.ts --watch
```

### ESLint

[ESLint](https://eslint.org/) is used to ensure code quality and enforce styling conventions.

To analyze all JavaScript files:

```
yarn run lint
```

Many issues can be fixed automatically by appending a `--fix` flag to the command:

```
yarn run lint --fix
```

## Forms

Login.gov is a form-heavy application, and there are some conventions to consider when implementing
a new form.

For details on back-end form processing, refer to the [equivalent section of the Back-end Architecture document](./backend.md#forms-formresponse-analytics-and-controllers).

### Form Rendering

[Simple Form](https://github.com/heartcombo/simple_form) is a wrapper which enhances [Ruby on Rails' default `form_for` helper](https://guides.rubyonrails.org/form_helpers.html),
including some nice conveniences:

- Standardizing markup layout for common input types
- Adding additional input types not available in Ruby on Rails
- Pre-filling values associated with form's associated record
- Displaying user-facing error messages after an invalid form submission

Typical usage should combine the `simple_form_for` helper with a record and associated block of form content:

```erb
<%= simple_form_for(@reset_password_form, url: user_password_path) do |f| %>
  <%= f.input :reset_password_token, as: :hidden %>
<% end >
```

If there is no record available, you can initialize `simple_form_for` with an empty string:

```erb
<%= simple_form_for('', url: user_password_path) do |f| %>
  <%= f.input :reset_password_token, as: :hidden %>
<% end >
```

### Form Validation

Use [standards-based client-side form validation](https://developer.mozilla.org/en-US/docs/Learn/Forms/Form_validation)
wherever possible. This is typically achieved using [input attributes](https://developer.mozilla.org/en-US/docs/Learn/Forms/Form_validation#using_built-in_form_validation)
to define validation constraints. For advanced validation, consider using the [`setCustomValidity`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/setCustomValidity)
function to assign or remove validation messages when an input's value changes.

A form's contents are validated when a user submits the form. Errors messages should only be
displayed at this point, and the user's focus should be drawn to the first field with an error
present. Error messages should be removed from a field when that field's value changes. It's
recommended that you use [`ValidatedFieldComponent`](#validatedfieldcomponent), which automatically
manages these behaviors.

#### ValidatedFieldComponent

The [`ValidatedFieldComponent` View Component](https://github.com/18F/identity-idp/blob/main/app/components/validated_field_component.rb)
is a wrapper component for Simple Form's `f.input` helper. It enhances the behavior of an input by:

- Displaying an error message on the page when form submission results in a validation error
- Moving focus to the first invalid field when form submission results in a validation error
- Providing default error messages for common validation constraints (e.g. required field missing)
- Allowing you to customize error messages associated with default field validation
- Creating a relationship between an input and its error message to ensure that the error is announced to assistive technology
- Resetting the error state when an input value changes

## Debugging

### Production Errors

JavaScript errors that occur in production environments are automatically logged to NewRelic. They are logged as an expected Ruby error with the class `FrontendLoggerError::FrontendError`.

There are two ways you can view these errors:

- [In the production APM "Errors" inbox, removing the filter which hides "expected" errors](https://onenr.io/0OQMVbbB9wG)
- [In the query builder, selecting from `TransactionError` with an error class of `FrontendErrorLogger::FrontendLogger`](https://onenr.io/0kjnpGG4awo)

Each error includes a few details to help you debug:

- `message`: Corresponds to [`Error#message`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error/message), and is usually a good summary to group by
- `name`: The subclass of the error (e.g. `TypeError`)
- `stack`: A stacktrace of the individual error instance
- `filename`: The URL of the script where the error was raised, if it's an uncaught error
- `error_id`: A unique identifier for tracing caught errors explicitly tracked

Note that NewRelic creates links in stack traces which are invalid, since they include the line and column number. If you encounter an "AccessDenied" error when clicking a stacktrace link, make sure to remove those details after the `.js` in your browser URL.

If an error includes `error_id`, you can use this to search in code for the corresponding call to `trackError` including that value as its `errorId` to trace where the error occurred.

Otherwise, debugging these stack traces can be difficult, since files in production are minified, and the stack traces include line numbers and columns for minified files. With the following steps, you can find a reference to the original code:

1. Download the minified JavaScript file referenced in the stack trace
   - Example: https://secure.login.gov/packs/document-capture-e41c853e.digested.js
2. Download the sourcemap file for the JavaScript by appending `.map` to the previous URL
   - Example: https://secure.login.gov/packs/document-capture-e41c853e.digested.js.map
3. Install the [`sourcemap-lookup` npm package](https://www.npmjs.com/package/sourcemap-lookup)
   - `npm i -g sourcemap-lookup`
4. Open a terminal window to the directory where you downloaded the files in steps 1 and 2
   - Example: `cd ~/Downloads`
5. Clean the sourcemap file to remove Webpack protocol details
   - Example: `sed -i '' 's/webpack:\/\/@18f\/identity-idp\///g' document-capture-e41c853e.digested.js.map`
6. Run the `sourcemap-lookup` command with a reference to the JavaScript file, line and column number, and specifying the source path to your local copy of `identity-idp`
   - Example: `sourcemap-lookup document-capture-e41c853e.digested.js:2:172098 --source-path=/path/to/identity-idp/`

The output of the `sourcemap-lookup` command should include "Original Position" and "Code Section" of the code which triggered the error.

## Fonts

Font files are optimized to remove unused character data. If a new character is added to content, the font files must be regenerated:

1. [Download Public Sans](https://public-sans.digital.gov/) and extract it to your project's `tmp/` directory
2. Install [glyphhanger](https://github.com/zachleat/glyphhanger) and its dependencies:
   1. `npm install -g glyphhanger`
   2. `pip install fonttools brotli`
3. Scrape content for character data:
   1. `make lint_font_glyphs`
4. Subset the original Public Sans fonts to include only used character data:
   1. `glyphhanger --formats=woff2 --subset="tmp/public-sans-v2/fonts/ttf/PublicSans-*.ttf" --whitelist="$(cat app/assets/fonts/glyphs.txt)"`
5. Replace font files with new subset fonts:
   1. `cd tmp/public-sans-v2/fonts/ttf`
   2. `find . -name "*-subset.woff2" -exec sh -c 'cp $1 "../../../../app/assets/fonts/public-sans/${1%-subset.woff2}.woff2"' _ {} \;`

At this point, your working directory should reflect changes to all of the files within `app/assets/fonts/public-sans`, and new or removed characters in `app/assets/fonts/glyphs.txt`. These changes should be committed to resolve the lint failure for character data.

## Devices

The application should support:

- All browsers with >1% usage according to our own analytics
- All device sizes

## Additional Resources

You can find additional frontend documentation in relevant places throughout the code:

- [`app/components/README.md`](../app/components/README.md)
- [`app/javascript/packages/README.md`](../app/javascript/packages/README.md)
- [`app/javascript/packs/README.md`](../app/javascript/packs/README.md)
