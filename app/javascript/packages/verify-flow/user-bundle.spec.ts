import { decodeUserBundle } from './user-bundle';

describe('decodeUserBundle', () => {
  it('decodes as base64url', () => {
    const token =
      'eyJzdWIiOiI0ODlhMDQxNS0zZDQ4LTRhM2UtYjhmNi05MzYyMzNmZmI0NDUiLCJhbGciOiJSUzI1NiJ9.' +
      'eyJwaWkiOnsiZmlyc3RfbmFtZSI6IkhhZsO-w7NyIiwibGFzdF9uYW1lIjoiQmrDtnJuc3NvbiIsInNzbiI6IjkwMDkwMDkwMCIsInBob25lIjoiKzEgNTEzLTU1NS0xMjEyIn0sIm1ldGFkYXRhIjp7ImFkZHJlc3NfdmVyaWZpY2F0aW9uX21lY2hhbmlzbSI6InBob25lIiwidXNlcl9waG9uZV9jb25maXJtYXRpb24iOnRydWUsInZlbmRvcl9waG9uZV9jb25maXJtYXRpb24iOnRydWV9fQ.' +
      'TEflx3z6BmqCqcIIvO_jlbQX6HZ1eAZPu7vhNZJjD7XWHbu973bALNolqwcOxrPFU2aOpxTyaLBDKpGzwAPQJg';

    const result = decodeUserBundle(token);

    expect(result).to.deep.equal({
      metadata: {
        address_verification_mechanism: 'phone',
        user_phone_confirmation: true,
        vendor_phone_confirmation: true,
      },
      pii: {
        first_name: 'Hafþór',
        last_name: 'Björnsson',
        phone: '+1 513-555-1212',
        ssn: '900900900',
      },
    });
  });

  it('returns null if token is not decodable', () => {
    const token = '';
    const result = decodeUserBundle(token);

    expect(result).to.be.null();
  });
});
