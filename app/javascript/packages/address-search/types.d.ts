import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import type { ReactNode } from 'react';

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

interface AddressSearchProps {
  registerField?: RegisterFieldCallback;
  onFoundAddress?: (address: LocationQuery | null) => void;
  onFoundLocations?: (locations: FormattedLocation[] | null | undefined) => void;
  onLoadingLocations?: (isLoading: boolean) => void;
  onError?: (error: Error | null) => void;
  disabled?: boolean;
  addressSearchURL: string;
  locationsURL: string;
}

interface InPersonLocationsProps {
  locations: FormattedLocation[] | null | undefined;
  onSelect;
  address: string;
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
