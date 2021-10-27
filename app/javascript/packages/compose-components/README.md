# `@18f/identity-compose-components`

A utility function to compose a set of React components and their props to a single component.

Convenient for flattening a deeply-nested arrangement of context providers, for example.

## Example

```jsx
const App = composeComponents(
  [FirstContext.Provider, { value: 1 }],
  [SecondContext.Provider, { value: 2 }],
  AppRoot,
);

render(App, document.getElementById('app-root'));
```
