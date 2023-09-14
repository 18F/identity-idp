import { Alert } from '@18f/identity-components';
import { snakeCase, formatLocations, transformKeys } from './utils';
import AddressInput from './components/address-input';
import AddressSearch from './components/address-search';
import InPersonLocations from './components/in-person-locations';
import NoInPersonLocationsDisplay from './components/no-in-person-locations-display';
import { requestUspsLocations } from './hooks/use-usps-locations';

export {
  Alert,
  AddressInput,
  InPersonLocations,
  NoInPersonLocationsDisplay,
  formatLocations,
  snakeCase,
  transformKeys,
  requestUspsLocations,
};

export default AddressSearch;
