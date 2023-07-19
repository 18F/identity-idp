import { base64ToArrayBuffer, arrayBufferToBase64, longToByteArray } from './converters';

const stringAsBase64 = 'Y3JlZGVudGlhbDEyMw==';
const stringAsArrayBuffer = Uint8Array.from([
  99, 114, 101, 100, 101, 110, 116, 105, 97, 108, 49, 50, 51,
]).buffer;

describe('base64ToArrayBuffer', () => {
  it('converts a base64 string to an equivalent array buffer', () => {
    expect(base64ToArrayBuffer(stringAsBase64)).to.deep.equal(stringAsArrayBuffer);
  });
});

describe('arrayBufferToBase64', () => {
  it('converts an array buffer to an equivalent string', () => {
    expect(arrayBufferToBase64(stringAsArrayBuffer)).to.equal(stringAsBase64);
  });
});

describe('longToByteArray', () => {
  it('converts a number to an equivalent byte array', () => {
    expect(longToByteArray(123)).to.deep.equal(new Uint8Array([123, 0, 0, 0, 0, 0, 0, 0]));
  });
});
