import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import HelpCenterContext, { Provider } from '@18f/identity-document-capture/context/help-center';

describe('document-capture/context/help-center', () => {
  it('assigns default context', () => {
    const { result } = renderHook(() => useContext(HelpCenterContext));

    expect(result.current).to.have.keys(['helpCenterRedirectURL', 'getHelpCenterURL']);
    expect(result.current.helpCenterRedirectURL).to.be.a('string');
    expect(result.current.getHelpCenterURL).to.be.a('function');
  });

  describe('getHelpCenterURL', () => {
    it('parameterizes category, article, location', () => {
      const { result } = renderHook(() => useContext(HelpCenterContext));

      const failureToProofURL = result.current.getHelpCenterURL({
        category: 'category',
        article: 'article',
        location: 'location',
      });

      expect(failureToProofURL).to.equal(
        `${window.location.origin}/?category=category&article=article&location=location`,
      );
    });
  });

  describe('Provider', () => {
    describe('getHelpCenterURL', () => {
      it('parameterizes category, article, location', () => {
        const { result } = renderHook(() => useContext(HelpCenterContext), {
          wrapper: ({ children }) => (
            <Provider
              value={{ helpCenterRedirectURL: 'http://example.com/redirect/?flow=example' }}
            >
              {children}
            </Provider>
          ),
        });

        const failureToProofURL = result.current.getHelpCenterURL({
          category: 'category',
          article: 'article',
          location: 'location',
        });

        expect(failureToProofURL).to.equal(
          'http://example.com/redirect/?flow=example&category=category&article=article&location=location',
        );
      });
    });
  });
});
