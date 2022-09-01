import type { AddressVerificationMethod } from './context/address-verification-method-context';

interface UserBundleMetadata {
  address_verification_mechanism: AddressVerificationMethod;
}

interface UserBundle {
  pii: Record<string, any>;

  metadata: UserBundleMetadata;
}

/**
 * Decodes a base64URL-encoded string.
 *
 * @see https://datatracker.ietf.org/doc/html/rfc4648#section-5
 *
 * @param base64URL Base64URL-encoded string.
 *
 * @return Decoded string.
 */
function decodeBase64URL(base64URL: string): string {
  const base64 = base64URL.replace(/-/g, '+').replace(/_/g, '/');

  // Fix the "Unicode Problem"
  // See: https://developer.mozilla.org/en-US/docs/Glossary/Base64#the_unicode_problem
  return new TextDecoder().decode(Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)));
}

/**
 * Decodes and parses a JWT token payload as the user bundle.
 *
 * @see https://datatracker.ietf.org/doc/html/rfc7519#section-7.2
 *
 * @param jwt JWT token.
 *
 * @return Decoded and parsed user bundle.
 */
export function decodeUserBundle(jwt: string): UserBundle | null {
  try {
    const [, payload] = jwt.split('.');
    return JSON.parse(decodeBase64URL(payload)) as UserBundle;
  } catch {
    return null;
  }
}
