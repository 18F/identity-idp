import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import MarketingSiteContext, { Provider } from './marketing-site';

describe('MarketingSiteContext', () => {
  it('assigns default context', () => {
    const { result } = renderHook(() => useContext(MarketingSiteContext));

    expect(result.current).to.have.keys(['getHelpCenterURL']);
    expect(result.current.getHelpCenterURL).to.be.a('function');
  });

  context('with securityAndPrivacyHowItWorksURL', () => {
    const securityAndPrivacyHowItWorksURL = 'http://example.com/security-and-privacy-how-it-works';
    it('assigns context values', () => {
      const { result } = renderHook(() => useContext(MarketingSiteContext), {
        wrapper: ({ children }) => (
          <Provider
            helpCenterRedirectURL="http://example.com/redirect/"
            securityAndPrivacyHowItWorksURL={securityAndPrivacyHowItWorksURL}
          >
            {children}
          </Provider>
        ),
      });

      expect(result.current).to.have.keys(['getHelpCenterURL', 'securityAndPrivacyHowItWorksURL']);
      expect(result.current.securityAndPrivacyHowItWorksURL).to.equal(
        securityAndPrivacyHowItWorksURL,
      );
      expect(result.current.getHelpCenterURL).to.be.a('function');
    });
  });

  describe('getHelpCenterURL', () => {
    it('parameterizes category, article, location', () => {
      const { result } = renderHook(() => useContext(MarketingSiteContext));

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
        const { result } = renderHook(() => useContext(MarketingSiteContext), {
          wrapper: ({ children }) => (
            <Provider helpCenterRedirectURL="http://example.com/redirect/?flow=example">
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
