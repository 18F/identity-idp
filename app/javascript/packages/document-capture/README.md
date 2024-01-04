# `@18f/identity-document-capture`

React components for displaying a user interface for a user to upload or capture photos of their state-issued identification.

## Usage

Render the included `<DocumentCapture />` React component. Most settings are expected to be configured by wrapping the component with one or more of the included context provider components.

```tsx
import { render } from 'react-dom';
import { DocumentCapture, AnalyticsContextProvider } from '@18f/identity-document-capture';

const appRoot = document.getElementById('app-root');

render(
  <AnalyticsContextProvider trackEvent={/* ... */}>
    {/* ... */}
    <DocumentCapture />
  </AnalyticsContextProvider>,
  appRoot
);
```
