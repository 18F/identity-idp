# `@18f/identity-address-search`

This is a npm module that provides a React UI component to search for USPS (United States Postal Service) locations. It allows you to retrieve USPS location information based on a full address.

Additionally, this module depends on existing backend services from the Login.gov project. Make sure to have the required backend services or mock services set up and running before using this module.

## Installation

You can install this module using npm:

```shell
npm install @18f/identity-address-search
```

Requires React version 18 or greater.

Requires @18f/identity-i18n.

## Usage

To use this component, provide callbacks to it for desired behaviors.

```typescript jsx
import AddressSearch from '@18f/identity-address-search';

// Render UI component

return(
    <>
    <AddressSearch
            addressSearchURL={addressSearchURL}
            disabled={disabledAddressSearchCallback}
            handleLocationSelect={handleLocationSelect}
            locationsURL={LOCATIONS_URL}
            noInPersonLocationsDisplay={noInPersonLocationsDisplay}
            onFoundLocations={setLocationResultsCallback}
            registerField={registerFieldCallback}
            resultsHeaderComponent={resultsHeaderComponent}
          />
    </>
);
```

## License

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.
