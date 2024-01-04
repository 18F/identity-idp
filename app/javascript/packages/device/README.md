# `@18f/identity-device`

Utilities for detecting details about the user's device.

## Usage

Import the desired utility function from the package:

```ts
import { isLikelyMobile } from '@18f/identity-device';

isLikelyMobile();
// true
```

## API

### `isIPad`

Returns true if the device is an iPad, or false otherwise.

iPadOS devices no longer list the correct user agent. As a proxy, we check for the incorrect one (Macintosh) then test the number of touchpoints, which for iPads will be 5.

### `isLikelyMobile`

Returns true if the device is likely a mobile device, or false otherwise. This is a rough approximation, using device user agent sniffing.

### `hasMediaAccess`

Returns true if the current device allows access to camera device APIs.

### `isCameraCapableMobile`

Returns true if the current device is assumed to be a mobile device where a camera is available, or false otherwise. This is a rough approximation, using device user agent sniffing and availability of camera device APIs.
