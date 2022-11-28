import { createContext } from 'react';

interface AcuantSdkUpgradeABTestContextValue {
  /**
   * Whether or not the A/B testing of using the newer Acuant
   * SDK version vs the older version is enabled
   */
  acuantSdkUpgradeABTestingEnabled: boolean;
  /**
   * Whether or not we should use the newer sdk version as opposed
   * to the older / current version
   */
  useNewerSdk: boolean;
}

export const NEW_SDK_VERSION = '11.7.1';
export const OLD_SDK_VERSION = '11.7.0';

export const AcuantSdkUpgradeABTestContext = createContext<AcuantSdkUpgradeABTestContextValue>({
  acuantSdkUpgradeABTestingEnabled: false,
  useNewerSdk: false,
});

AcuantSdkUpgradeABTestContext.displayName = 'AcuantSdkUpgradeABTestContext';

export default AcuantSdkUpgradeABTestContext;
export const AcuantSdkUpgradeABTestContextProvider = AcuantSdkUpgradeABTestContext.Provider;
