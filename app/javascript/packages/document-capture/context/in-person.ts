import { createContext } from 'react';

export interface InPersonContextProps {
  /**
   * URL to in-person proofing alternative flow, if enabled.
   */
  inPersonURL?: string;

  /**
   * Post Office location search endpoint URL
   */
  locationsURL: string;

  /**
   * Address search endpoint URL
   */
  addressSearchURL: string;

  /**
   * Whether the message indicating an outage should be displayed
   */
  inPersonOutageMessageEnabled: boolean;

  /**
   * Date communicated to users regarding expected update about their enrollment after an outage
   */
  inPersonOutageExpectedUpdateDate?: string;

  /**
   * When true users must enter a full address when searching for a Post Office location
   */
  inPersonFullAddressEntryEnabled: boolean;

  /**
   * Collection of US states and territories
   * Each item is [Long name, abbreviation], e.g. ['Ohio', 'OH']
   */
  usStatesTerritories: Array<[string, string]>;

  /**
   * When true users are directed to the beginning of the IPP flow if they choose
   * Opt-in IPP if in_person_proofing_opt_in_enabled is enabled
   */
  skipDocAuth?: boolean;

  /**
   * URL for Opt-in IPP, used when in_person_proofing_opt_in_enabled is enabled
   */
  howToVerifyURL?: string;
}

const InPersonContext = createContext<InPersonContextProps>({
  locationsURL: '',
  addressSearchURL: '',
  inPersonOutageMessageEnabled: false,
  inPersonFullAddressEntryEnabled: false,
  usStatesTerritories: [],
});

InPersonContext.displayName = 'InPersonContext';

export default InPersonContext;
