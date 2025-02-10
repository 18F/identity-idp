import { base64ToArrayBuffer } from './converters';

/**
 * Converts an array of base64-encoded strings to credential descriptors.
 *
 * @param credentials Strings to convert.
 * @return Converted credentials.
 */
const extractCredentials = (credentials: string[]): PublicKeyCredentialDescriptor[] =>
  credentials.map((credential) => ({
    type: 'public-key',
    id: base64ToArrayBuffer(credential),
  }));

export default extractCredentials;
