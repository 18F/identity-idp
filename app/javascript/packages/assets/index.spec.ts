import { getAssetPath } from './index';

describe('getAssetPath', () => {
  beforeEach(() => {
    delete getAssetPath.cache;
  });

  it('returns undefined', () => {
    expect(getAssetPath('foo.svg')).to.be.undefined();
  });

  context('with global assets not including the provided asset', () => {
    beforeEach(() => {
      document.body.innerHTML = '<script type="application/json" data-asset-map>{}</script>';
    });

    it('returns undefined for missing assets', () => {
      expect(getAssetPath('foo.svg')).to.be.undefined();
    });
  });

  context('with global assets including the provided asset', () => {
    beforeEach(() => {
      document.body.innerHTML =
        '<script type="application/json" data-asset-map>{"foo.svg":"bar.svg"}</script>';
    });

    it('returns the mapped asset path', () => {
      expect(getAssetPath('foo.svg')).to.equal('bar.svg');
    });
  });
});
