import { getAssetPath } from './index';

describe('getAssetPath', () => {
  beforeEach(() => {
    delete getAssetPath.cache;
  });

  it('returns the original path argument', () => {
    expect(getAssetPath('foo.svg')).to.be.equal('foo.svg');
  });

  context('with global assets not including the provided asset', () => {
    beforeEach(() => {
      document.body.innerHTML = '<script type="application/json" data-asset-map>{}</script>';
    });

    it('returns the original path argument for missing assets', () => {
      expect(getAssetPath('foo.svg')).to.be.equal('foo.svg');
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
