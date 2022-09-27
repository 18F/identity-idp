# `@18f/identity-react-i18n`

`@18f/identity-react-i18n` is a superset of the functionality provided by [`@18f/identity-i18n`](https://github.com/18F/identity-idp/tree/main/app/javascript/packages/i18n), tailored for use in a React application.

React-specific support includes:

- A `I18nContext` context provider to customize locale data within a React context scope.
- A corresponding `useI18n` hook to consume locale data from the closest `I18nContext`.
- A `formatHTML` helper to replace HTML elements in locale strings with live React elements.

## Usage

### `formatHTML`

Given an HTML string and an object of tag names to React component, returns a new React node where the mapped tag names are replaced by the resulting element of the rendered component.

Note that this is a very simplistic interpolation of HTML. It only supports self-closing and well-balanced, non-nested tag names, where there are no attributes or excess whitespace within the tag names. The tag name cannot contain regular expression special characters.

While the subject markup itself cannot contain attributes, the return value of the component can be any valid React element, with or without additional attributes.

```tsx
formatHTML('Hello <lg-sparkles>world</lg-sparkles>!', {
  'lg-sparkles': ({children}) => <span className="lg-sparkles">{children}</span>
});
```

### `I18nContext`

```tsx
function App({ children }) {
  return (
    <I18nContext.Provider value={{ string_key: 'translation' }}>
      {children}
    </I18nContext.Provider>
  );
}
```

### `useI18n`

```tsx
function MyComponent() {
  const { t } = useI18n();

  return <div>{t('string_key')}</div>;
}
```
