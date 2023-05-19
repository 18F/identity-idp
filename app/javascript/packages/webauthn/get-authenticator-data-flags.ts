/* eslint-disable no-bitwise */

/**
 * @see https://w3c.github.io/webauthn/#authdata-flags
 */
interface AuthenticatorDataFlags {
  /**
   * @see https://www.w3.org/TR/webauthn-2/#up
   */
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
