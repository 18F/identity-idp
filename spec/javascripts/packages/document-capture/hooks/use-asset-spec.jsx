import { renderHook } from '@testing-library/react-hooks';
import useAsset from '@18f/identity-document-capture/hooks/use-asset';
import AssetContext from '@18f/identity-document-capture/context/asset';

describe('document-capture/hooks/use-asset', () => {
  describe('getAssetPath', () => {
    it('returns undefined if the asset is not known', () => {
      const { result } = renderHook(() => useAsset());

      const { getAssetPath } = result.current;

      expect(getAssetPath('unknown.png')).to.be.undefined();
    });

    it('returns mapped src if known by context', () => {
      const { result } = renderHook(() => useAsset(), {
        wrapper: ({ children }) => (
          <AssetContext.Provider value={{ 'icon.png': 'icon-12345.png' }}>
            {children}
          </AssetContext.Provider>
        ),
      });

      const { getAssetPath } = result.current;

      expect(getAssetPath('icon.png')).to.equal('icon-12345.png');
    });
  });
});
