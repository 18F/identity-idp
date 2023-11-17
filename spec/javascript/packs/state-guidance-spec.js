import { expect } from 'chai';
import {
  showOrHideJurisdictionExtras,
  showOrHidePuertoRicoExtras,
} from '../../../app/javascript/packs/state-guidance';

describe('state-guidance', () => {
  describe('showOrHidePuertoRicoExtras', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div class="container">
          <div>
            <select class="address-state-selector">Select Dropdown</select>
          </div>
          <div class="puerto-rico-extras display-none"></div>
        </div>
      `;
    });

    it('includes class display-none if state is not PR', () => {
      const forStateCode = 'NY';
      showOrHidePuertoRicoExtras(forStateCode);
      const prExtrasElemClassList = document.querySelector('.puerto-rico-extras')?.classList;

      expect(prExtrasElemClassList).to.contain(['puerto-rico-extras', 'display-none']);
    });

    it('does not include class display-none if state is PR', () => {
      const forStateCode = 'PR';
      showOrHidePuertoRicoExtras(forStateCode);
      const prExtrasElemClassList = document.querySelector('.puerto-rico-extras')?.classList;

      expect(prExtrasElemClassList).to.contain(['puerto-rico-extras']);
    });
  });

  describe('showOrHideJurisdictionExtras', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div class="container">
          <div>
            <select class="jurisdiction-state-selector">Select Dropdown</select>
          </div>
          <div class="jurisdiction-extras">
            <span data-state="default">Default help text</span>
            <span data-state="CA" class="display-none">CA help text</span>
            <span data-state="TX" class="display-none">TX help text</span>
          </div>
        </div>
      `;
    });

    it('includes Texas specific hint text when Texas is selected', () => {
      const jurisdictionCode = 'TX';
      showOrHideJurisdictionExtras(jurisdictionCode);

      const allHintTexts = document.querySelectorAll('.jurisdiction-extras [data-state]');
      const texasText = document.querySelectorAll('.jurisdiction-extras [data-state=TX]');
      const nonTexasText = document.querySelectorAll(
        '.jurisdiction-extras [data-state].display-none',
      );

      expect(texasText.length).to.eq(1);
      expect(texasText[0].classList.contains('display-none')).to.eq(false);

      expect(nonTexasText.length + texasText.length).to.eq(allHintTexts.length);
    });

    it('includes default hint text when no state is selected', () => {
      const jurisdictionCode = '';
      showOrHideJurisdictionExtras(jurisdictionCode);

      const allHintTexts = document.querySelectorAll('.jurisdiction-extras [data-state]');
      const defaultText = document.querySelectorAll('.jurisdiction-extras [data-state=default]');
      const nonDefaultText = document.querySelectorAll(
        '.jurisdiction-extras [data-state].display-none',
      );

      expect(defaultText.length).to.eq(1);
      expect(defaultText[0].classList.contains('display-none')).to.eq(false);

      expect(nonDefaultText.length + defaultText.length).to.eq(allHintTexts.length);
    });

    it('includes default hint text when a state without a state specific hint is selected', () => {
      const jurisdictionCode = 'NY';
      showOrHideJurisdictionExtras(jurisdictionCode);
      const elementInnerHtml = document.querySelector('.jurisdiction-extras')?.textContent;

      const allHintTexts = document.querySelectorAll('.jurisdiction-extras [data-state]');
      const defaultText = document.querySelectorAll('.jurisdiction-extras [data-state=default]');
      const nonDefaultText = document.querySelectorAll(
        '.jurisdiction-extras [data-state].display-none',
      );

      expect(defaultText.length).to.eq(1);
      expect(defaultText[0].classList.contains('display-none')).to.eq(false);

      expect(nonDefaultText.length + defaultText.length).to.eq(allHintTexts.length);
    });
  });
});
