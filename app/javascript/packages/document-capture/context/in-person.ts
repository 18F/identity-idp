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
   * Whether the message indicating an outage should be displayed
   */
  inPersonOutageMessageEnabled: boolean;

  /**
   * Date communicated to users regarding expected update about their enrollment after an outage
   */
  inPersonOutageExpectedUpdateDate?: string;

  /**
   * When true a user has entered ipp by opting in
   */
  optedInToInPersonProofing: boolean;

  /**
   * Collection of US states and territories
   * Each item is [Long name, abbreviation], e.g. ['Ohio', 'OH']
   */
  usStatesTerritories: Array<[string, string]>;

  /**
   * When skipDocAuthFromHowToVerify is true and in_person_proofing_opt_in_enabled is true,
   * users are directed to the beginning of the IPP flow. This is set to true when
   * they choose Opt-in IPP on the new How To Verify page
   */
  skipDocAuthFromHowToVerify?: boolean;

  /**
   * Flag set when user select IPP from handoff page when IPP is available
   * and selfie is required
   */
  skipDocAuthFromHandoff?: boolean;

  /**
   * Flag set when user select IPP from the Socure Hybrid page when IPP is available
   */
  skipDocAuthFromSocure?: boolean;

  /**
   * URL for Opt-in IPP, used when in_person_proofing_opt_in_enabled is enabled
   */
  howToVerifyURL?: string;

  /**
   * URL to return back to the Socure timeout page from Opt-in IPP
   */
  socureErrorsTimeoutURL?: string;

  /**
   * URL for going back to previous steps in Doc Auth, like handoff and howToVerify
   */
  previousStepURL?: string;
}

const InPersonContext = createContext<InPersonContextProps>({
  locationsURL: '',
  inPersonOutageMessageEnabled: false,
  optedInToInPersonProofing: false,
  usStatesTerritories: [],
});

InPersonContext.displayName = 'InPersonContext';

export default InPersonContext;
