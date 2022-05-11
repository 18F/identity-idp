# `@18f/identity-i18n`

JavaScript implementation of a Rails-like localization utility.

When paired with [`@18f/identity-rails-i18n-webpack-plugin`](https://github.com/18F/identity-idp/tree/main/app/javascript/packages/rails-i18n-webpack-plugin), it provides a seamless localization experience to retrieve locale data from [Rails locale data](https://github.com/18F/identity-idp/tree/main/config/locales).

## Usage

Usage should provide a behavior similar to [Rails Internationalization](https://guides.rubyonrails.org/i18n.html), where a given key would be expected to match locale data based on the folder structure found in `config/locales`.

For example, a key of `foo.bar.baz`, would match the file at `config/locales/foo/en.yml` (for English locales), whose content includes...

```yml
en:
  foo:
    bar:
      baz: Message
```

### Basic

Call the translate function with a key to retrieve the translated message.

```yml
# config/locales/messages/en.yml
en:
  messages:
    greeting: Hello world!
```

```ts
import { t } from '@18f/identity-i18n';

t('messages.greeting');
// "Hello world!"
```

### Interpolation

Include an object of variables to interpolate those values in the matched entry.

```yml
# config/locales/messages/en.yml
en:
  messages:
    greeting: Hello %{recipient}!
```

```ts
import { t } from '@18f/identity-i18n';

t('messages.greeting', { recipient: 'world' });
// "Hello world!"
```

### Pluralization

An entry which is an object including `one` or `other` keys will automatically choose the correct message based on the `count` variable.

```yml
# config/locales/messages/en.yml
en:
  messages:
    greeting:
      one: Hello to you!
      other: Hello to all!
```

```ts
import { t } from '@18f/identity-i18n';

t('messages.greeting', { count: 1 });
// "Hello to you!"

t('messages.greeting', { count: 2 });
// "Hello to all!"
```

### Array Values

An entry may be a single string or an array of strings. Passing an array of key(s) will return an array of messages.

```yml
# config/locales/messages/en.yml
en:
  messages:
    greetings:
      - Hello!
      - Howdy!
```

```ts
import { t } from '@18f/identity-i18n';

t(['messages.greetings']);
// ["Hello!", "Howdy!"]
```
