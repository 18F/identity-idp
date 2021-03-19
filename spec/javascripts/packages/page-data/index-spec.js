import { getPageData } from '@18f/identity-page-data';

describe('getPageData', () => {
  context('page data exists', () => {
    beforeEach(() => {
      document.body.innerHTML = '<script data-foo-bar-baz="value"></script>';
    });

    it('returns value', () => {
      const result = getPageData('fooBarBaz');

      expect(result).to.equal('value');
    });
  });

  context('page data does not exist', () => {
    it('returns undefined', () => {
      const result = getPageData('fooBarBaz');

      expect(result).to.be.undefined();
    });
  });
});
