import { encodeInput } from '../../../app/javascript/packs/personal-key-input-encoder';

describe('personal-key-input-encoder', () => {
  it('removes Crockford-encoded characters', () => {
    expect(encodeInput('LlIi-1111-1111-1111')).to.equal('1111-1111-1111-1111');

    expect(encodeInput('LLII-0000-0000-llii')).to.equal('1111-0000-0000-1111');

    expect(encodeInput('1234-1234-1234-1234')).to.equal('1234-1234-1234-1234');

    expect(encodeInput('7P41-1JFN-W7JA-DVR2')).to.equal('7P41-1JFN-W7JA-DVR2');
  });
});
