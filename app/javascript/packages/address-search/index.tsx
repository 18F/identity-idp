import useUspsLocations from './hooks/use-usps-locations';
import AddressSearch from './components/address-search';
import { snakeCase, formatLocations, transformKeys } from './utils';

export { InPersonLocations } from '@18f/identity-document-capture';
export { useUspsLocations, snakeCase, formatLocations, transformKeys };

export default AddressSearch;
