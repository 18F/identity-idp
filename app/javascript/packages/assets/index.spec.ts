import { usePropertyValue } from '@18f/identity-test-helpers';
import { getAssetPath } from './index';

describe('getAssetPath', () => {
  it('returns undefined', () => {
    expect(getAssetPath('foo.svg')).to.be.undefined();
  });

  context('with global assets not including the provided asset', () => {
    usePropertyValue(global as any, '_asset_paths', {});

    it('returns undefined for missing assets', () => {
      expect(getAssetPath('foo.svg')).to.be.undefined();
    });
  });

  context('with global assets including the provided asset', () => {
    usePropertyValue(global as any, '_asset_paths', { 'foo.svg': 'bar.svg' });

    it('returns the mapped asset path', () => {
      expect(getAssetPath('foo.svg')).to.equal('bar.svg');
    });
  });
});
