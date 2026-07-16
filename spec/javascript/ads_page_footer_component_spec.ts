import {
  navigateFooterSelect,
  resolveFooterNavigationUrl,
} from '../../app/components/ads_page_footer_component';

describe('AdsPageFooterComponent', () => {
  describe('resolveFooterNavigationUrl', () => {
    const baseUrl = 'https://secure.login.gov/account';

    it('resolves relative and absolute web destinations', () => {
      expect(resolveFooterNavigationUrl('/help', baseUrl)).to.equal(
        'https://secure.login.gov/help',
      );
      expect(resolveFooterNavigationUrl('https://www.gsa.gov', baseUrl)).to.equal(
        'https://www.gsa.gov/',
      );
    });

    it('rejects empty, malformed, and non-web destinations', () => {
      expect(resolveFooterNavigationUrl('', baseUrl)).to.be.undefined();
      expect(resolveFooterNavigationUrl('https://%', baseUrl)).to.be.undefined();
      expect(
        resolveFooterNavigationUrl(['java', 'script:alert(1)'].join(''), baseUrl),
      ).to.be.undefined();
    });
  });

  describe('navigateFooterSelect', () => {
    const createLocation = () => {
      const destinations: string[] = [];
      const location = {
        href: 'https://secure.login.gov/account',
        assign: (value: string | URL) => destinations.push(value.toString()),
      };

      return { destinations, location };
    };

    it('navigates to a valid selection and resets the More control', () => {
      const select = document.createElement('select');
      select.dataset.adsFooterNavigationReset = 'true';
      select.innerHTML = '<option value="">More</option><option value="/help">Help</option>';
      select.selectedIndex = 1;
      const { destinations, location } = createLocation();

      expect(navigateFooterSelect(select, location)).to.be.true();
      expect(destinations).to.deep.equal(['https://secure.login.gov/help']);
      expect(select.selectedIndex).to.equal(0);
    });

    it('ignores an invalid selection', () => {
      const select = document.createElement('select');
      select.innerHTML = `<option value="${['java', 'script:alert(1)'].join('')}">Unsafe</option>`;
      const { destinations, location } = createLocation();

      expect(navigateFooterSelect(select, location)).to.be.false();
      expect(destinations).to.be.empty();
    });
  });
});
