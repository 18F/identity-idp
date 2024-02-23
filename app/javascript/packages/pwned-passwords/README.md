# `@18f/identity-pwned-passwords`

Utilities and command-line tools for downloading the [HaveIBeenPwned Pwned Passwords](https://haveibeenpwned.com/Passwords) breached passwords dataset.

## Usage

### Command-Line Interface

Run the included `download-pwned-passwords` executable with optional flags.

```
yarn download-pwned-passwords
```

Flags:

- `--out-file`, `-o`: Write hashes to a specific file, instead of stdout. Also enables progress bar display during download.
- `--max-size`, `-n`: Maximum number of top hashes to retrieve (default: 3,000,000)
- `--concurrency`: Number of parallel downloaders to use to retrieve data (default: 40)
- `--range-start`: Minimum hash prefix for [HaveIBeenPwned Range API](https://haveibeenpwned.com/API/v3#SearchingPwnedPasswordsByRange) (default: 00000)
- `--range-end`: Inclusive maximum hash prefix for [HaveIBeenPwned Range API](https://haveibeenpwned.com/API/v3#SearchingPwnedPasswordsByRange) (default: fffff)

### API

Import the `Downloader` class, and construct with any relevant options to control download behavior. The downloader's `download` function will resolve with an iterable set of password hashes.

```ts
import { Downloader } from '@18f/identity-pwned-passwords';

const downloader = new Downloader(/* ...options */);
const hashes = Array.from(await downloader.download());
```

Available constructor options:

- `maxRetry`: Number of attempts to retry upon failed download for a given range (default: 5)
- `maxSize`: Maximum number of top hashes to retrieve (default: 3,000,000)
- `concurrency`: Number of parallel downloaders to use to retrieve data (default: 40)
- `rangeStart`: Minimum hash prefix for [HaveIBeenPwned Range API](https://haveibeenpwned.com/API/v3#SearchingPwnedPasswordsByRange) (default: 00000)
- `rangeEnd`: Inclusive maximum hash prefix for [HaveIBeenPwned Range API](https://haveibeenpwned.com/API/v3#SearchingPwnedPasswordsByRange) (default: fffff)
