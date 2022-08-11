# Packs

Packs are the entrypoints for application JavaScript bundles. Each file in this directory is compiled and made available to the Rails application through the `javascript_packs_tag_once` helper:

```erb
<%= javascript_packs_tag_once('verify-personal-key') %>
```

The contents of a pack are expected to import from [package(s)](../packages) relevant to implement a particular feature or page behavior. Unlike a package, a pack is intended to serve as the integration between the Rails application and its JavaScript behavior, and should query for page elements and application configuration necessary to initialize those packages.

```tsx
import { render } from 'react-dom';
import { FormSteps } from '@18f/identity-form-steps';

const appRoot = document.getElementById('app-root');

render(<FormSteps initialValues={{ personalKey: appRoot.dataset.personalKey }} />, appRoot);
```
