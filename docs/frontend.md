# Front-end Architecture

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
- Variables should be named as camelCase, e.g. `const myFavoriteNumber = 1;`.
   - Only the first letter of an abbreviation should be capitalized, e.g. `const userId = 10;`.
   - All letters of an acronym should be capitalized, e.g. `const siteURL = 'https://example.com';`.
- Classes and React components should be named as PascalCase (upper camel case), e.g. `class MyCustomElement {}`.
- Constants should be named as SCREAMING_SNAKE_CASE, e.g. `const MEANING_OF_LIFE = 42;`.
- TypeScript enums should be named as PascalCase with SCREAMING_SNAKE_CASE members, e.g. `enum Color { RED = '#f00'; }`.

Related: [Component Naming Conventions](#naming)

### Prettier

[Prettier](https://prettier.io/) is an opinionated code formatter which simplifies adherence to
JavaScript style standards, both for the developer and for the reviewer. As a developer, it can
eliminate the effort involved with applying correct formatting. As a reviewer, it avoids most
debates over code style, since there is a consistent style being enforced through the adopted
tooling.

Prettier works reasonably well in combination with Airbnb's JavaScript standards. In the few cases
where conflicts occur, formatting rules may be disabled to err toward Prettier conventions when an
option is not configurable.

Prettier is integrated with [the project's linting setup](#eslint). Most issues can be resolved
automatically by running `yarn run lint --fix`. You may also consider one of the
[available editor integrations](https://prettier.io/docs/en/editors.html), which can simplify your
workflow to apply formatting automatically on save.

### Yarn Workspaces

[Workspaces](https://classic.yarnpkg.com/en/docs/workspaces/) allow a developer to create and
organize code which is used just like any other NPM package, but which doesn't require the overhead
involved in publishing those modules and keeping versions in sync across multiple repositories. The
IDP uses Yarn workspaces to keep JavaScript code organized, reusable, and to encourage good coding
practices in abstractions.

In practice:

- All folders within `app/javascript/packages` are treated as workspace packages.
- Each package should have its own `package.json` that includes...
  - ...a `name` starting with `@18f/identity-` and ending with the name of the package folder.
  - ...a listing of its own dependencies, including to other workspace packages using
    [`file:` prefix](https://classic.yarnpkg.com/en/docs/cli/add/).
  - ...[`"private": true`](https://docs.npmjs.com/files/package.json#private) if the workspace
    package is not intended to be published to NPM.
  - ...a value for the `version` field, since it is required. The value value can be anything, and
    `"1.0.0"` is a good default.
- Each package should include an `index.js` which serves as the entry-point and public API for the
  package.

A package might have a corresponding file by the same package name contained within
`app/javascript/packs` that serves as the integration point between packages and the Rails
application. This is to encourage packages to be reusable, where the file in `packs` contains any
logic required to wire the package to the running Rails application. Because Yarn will alias
workspace packages using symlinks, you can reference a package using the name you assigned using the
guidelines above for `package.json` `name` field (for example,
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
performance impact on users. Similarly, consider using a tool like [`yarn-deduplicate`](https://github.com/scinos/yarn-deduplicate)
to deduplicate resolved package versions within the Yarn lockfile.

### Localization

See [`@18f/identity-i18n` package documentation](../app/javascript/packages/i18n/README.md).

### Analytics

See [`@18f/identity-analytics` package documentation][analytics_package] for code examples detailing
how to track an event in JavaScript.

Any event logged from the frontend must be added to the `EVENT_MAP` allowlist in [`FrontendLogController`][frontend_log_controller.rb].
This mapping associates the event name logged from the frontend with the corresponding method from
[AnalyticsEvents][analytics_events.rb] to be called. All properties will be passed automatically to
the event from the frontend as long as they are defined in the method argument signature.

There may be some situations where you need to append a value known by the server to an event logged
in the frontend, such as an A/B test bucket descriptor. In these scenarios, you have a few options:

1. Add the value to the page markup, such as through an [HTML `data-` attribute][data_attributes],
and reference that attribute in JavaScript.
2. Define the mapped value in `EVENT_MAP` to a service class, such as how [frontend error logging][frontend_error_logging]
is implemented.
3. Implement a mixin to intercept and override the default behavior of an analytics event, such as
how [`Idv::AnalyticsEventEnhancer`][analytics_events_enhancer.rb] is implemented.

[analytics_package]: ../app/javascript/packages/analytics/README.md
[frontend_log_controller.rb]: https://github.com/18F/identity-idp/blob/main/app/controllers/frontend_log_controller.rb
[analytics_events.rb]: https://github.com/18F/identity-idp/blob/main/app/services/analytics_events.rb
[data_attributes]: https://developer.mozilla.org/en-US/docs/Learn/HTML/Howto/Use_data_attributes
[frontend_error_logging]: https://github.com/18F/identity-idp/blob/9c17164c0b8d9b4aefad74dde1a521c111b53aac/app/controllers/frontend_log_controller.rb#L14
[analytics_events_enhancer.rb]: https://github.com/18F/identity-idp/blob/main/app/services/idv/analytics_events_enhancer.rb

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
- ViewComponent files should be named `app/components/[example_name]_component.rb`
- Stylesheet files should be named `app/assets/stylesheets/components/_[example-name].scss`
- Stylesheet selectors should use `[example-name]` as the ["block name" in BEM](https://en.bem.info/methodology/naming-convention/#two-dashes-style)
- React components should be named `<[ExampleName] />`
- React component files should be named `app/javascript/packages/[example-name]/[example-name].tsx`
- Web components should be named `[ExampleName]Element`
- Web components files should be named `app/javascript/packages/[example-name]/[example-name]-element.ts`

For example, consider a **Password Input** component:

- A ViewComponent implementation would be named `PasswordInputComponent`
- A ViewComponent file would be named `app/components/password_input_component.rb`
- A stylesheet file would be named `app/assets/stylesheets/componewnts/_password-input.scss`
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

Note that NewRelic creates links in stack traces which are invalid, since they include the line and column number. If you encounter an "AccessDenied" error when clicking a stacktrace link, make sure to remove those details after the `.js` in your browser URL.

Debugging these stack traces can be difficult, since files in production are minified, and the stack traces include line numbers and columns for minified files. With the following steps, you can find a reference to the original code:

1. Download the minified JavaScript file referenced in the stack trace
   - Example: https://secure.login.gov/packs/js/document-capture-e41c853e.digested.js
2. Download the sourcemap file for the JavaScript by appending `.map` to the previous URL
   - Example: https://secure.login.gov/packs/js/document-capture-e41c853e.digested.js.map
3. Install the [`sourcemap-lookup` npm package](https://www.npmjs.com/package/sourcemap-lookup)
   - `npm i -g sourcemap-lookup`
4. Open a terminal window to the directory where you downloaded the files in steps 1 and 2
   - Example: `cd ~/Downloads`
5. Clean the sourcemap file to remove Webpack protocol details
   - Example: `sed -i '' 's/webpack:\/\/@18f\/identity-idp\///g' document-capture-e41c853e.digested.js.map`
6. Run the `sourcemap-lookup` command with a reference to the JavaScript file, line and column number, and specifying the source path to your local copy of `identity-idp`
   - Example: `sourcemap-lookup document-capture-e41c853e.digested.js:2:172098 --source-path=/path/to/identity-idp/`

The output of the `sourcemap-lookup` command should include "Original Position" and "Code Section" of the code which triggered the error.

## Devices

The application should support:

- All browsers with >1% usage according to our own analytics
- All device sizes

## Additional Resources

You can find additional frontend documentation in relevant places throughout the code:

- [`app/components/README.md`](../app/components/README.md)
- [`app/javascript/packages/README.md`](../app/javascript/packages/README.md)
- [`app/javascript/packs/README.md`](../app/javascript/packs/README.md)
