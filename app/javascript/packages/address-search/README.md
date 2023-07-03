# `@18f/identity-address-search`

This is a npm module that provides a React UI component to search for USPS (United States Postal Service) locations using the ArcGIS API. It allows you to retrieve USPS location information based on a full address.

Additionally, this module depends on existing backend services from the Login.gov project. Make sure to have the required backend services or mock services set up and running before using this module.

## Installation

You can install this module using npm:

```shell
npm install @18f/identity-address-search
```

Requires React version 17 or greater.

## Usage

To use this component, provide callbacks to it for desired behaviors.

```typescript jsx
import AddressSearch from '@18f/identity-address-search';

// Render UI component

return(
    <>
    <AddressSearch
            registerField={registerFieldCallback}
            onFoundAddress={setFoundAddressCallback}
            onFoundLocations={setLocationResultsCallback}
            onLoadingLocations={setLoadingLocationsCallback}
            onError={setApiErrorCallback}
            disabled={disabledAddressSearchCallback}
          />
    </>
);
```

## License

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.
