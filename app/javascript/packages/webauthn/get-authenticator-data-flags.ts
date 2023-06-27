/* eslint-disable no-bitwise */

 interface AuthenticatorDataFlags {
    up: boolean;
  
    /**
     * @see https://www.w3.org/TR/webauthn-2/#uv
     */
    uv: boolean;
  
    /**
     * @see https://w3c.github.io/webauthn/#ref-for-authdata-flags-be
     */
    be: boolean;
  
    /**
     * @see https://w3c.github.io/webauthn/#ref-for-authdata-flags-bs
     */
    bs: boolean;
  
    /**
     * @see https://w3c.github.io/webauthn/#ref-for-authdata-flags-at
     */
    at: boolean;
  
    /**
     * @see https://w3c.github.io/webauthn/#ref-for-authdata-flags-ed
     */
    ed: boolean;
  }
  
  function getAuthenticatorDataFlags(authenticatorData: ArrayBuffer): AuthenticatorDataFlags {
    const flagsBitfield = new Uint8Array(authenticatorData)[32];
    console.log(flagsBitfield)
    return {
      up: !!(flagsBitfield & (1 << 0)),
      uv: !!(flagsBitfield & (1 << 2)),
      be: !!(flagsBitfield & (1 << 3)),
      bs: !!(flagsBitfield & (1 << 4)),
      at: !!(flagsBitfield & (1 << 6)),
      ed: !!(flagsBitfield & (1 << 7)),
    };
  }
  
  export default getAuthenticatorDataFlags;