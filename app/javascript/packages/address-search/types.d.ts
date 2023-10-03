import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import type { ComponentType, Dispatch, SetStateAction, ReactNode } from 'react';

interface FormattedLocation {
  formattedCityStateZip: string;
  distance: string;
  id: number;
  name: string;
  saturdayHours: string;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
  isPilot: boolean;
}

interface PostOffice {
  address: string;
  city: string;
  distance: string;
  name: string;
  saturday_hours: string;
  state: string;
  sunday_hours: string;
  weekday_hours: string;
  zip_code_4: string;
  zip_code_5: string;
  is_pilot: boolean;
}

interface LocationQuery {
  streetAddress: string;
  city: string;
  state: string;
  zipCode: string;
  address: string;
}

interface Location {
  street_address: string;
  city: string;
  state: string;
  zip_code: string;
  address: string;
}

interface AddressInputProps {
  registerField?: RegisterFieldCallback;
  onFoundAddress?: (address: LocationQuery | null) => void;
  onFoundLocations?: (locations: FormattedLocation[] | null | undefined) => void;
  onLoadingLocations?: (isLoading: boolean) => void;
  onError?: (error: Error | null) => void;
  disabled?: boolean;
  addressSearchURL: string;
  locationsURL: string;
}

interface AddressSearchProps {
  addressSearchURL: string;
  disabled: boolean;
  handleLocationSelect: ((e: any, id: number) => Promise<void>) | null | undefined;
  locationsURL: string;
  noInPersonLocationsDisplay?: ComponentType<{ address: string }>;
  onFoundLocations: Dispatch<SetStateAction<FormattedLocation[] | null | undefined>>;
  registerField: RegisterFieldCallback;
  resultsHeaderComponent?: ComponentType;
}

interface InPersonLocationsProps {
  address: string;
  locations: FormattedLocation[] | null | undefined;
  noInPersonLocationsDisplay: ComponentType<{ address: string }>;
  onSelect;
  resultsHeaderComponent?: ComponentType;
}

interface LocationCollectionItemProps {
  distance?: string;
  formattedCityStateZip: string;
  handleSelect?: (event: React.MouseEvent, selection: number) => void;
  name?: string;
  saturdayHours: string;
  selectId: number;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
}

interface LocationCollectionProps {
  className?: string;

  children?: ReactNode;
}

interface FullAddressSearchProps {
  disabled: boolean;
  handleLocationSelect: ((e: any, id: number) => Promise<void>) | null | undefined;
  locationsURL: string;
  noInPersonLocationsDisplay?: ComponentType<{ address: string }>;
  onFoundLocations: Dispatch<SetStateAction<FormattedLocation[] | null | undefined>>;
  registerField: RegisterFieldCallback;
  resultsHeaderComponent?: ComponentType;
  usStatesTerritories: string[][];
}
