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
          <div class="puerto-rico-extras" hidden></div>
        </div>
      `;
    });

    it('hides extras if state is not PR', () => {
      const forStateCode = 'NY';
      showOrHidePuertoRicoExtras(forStateCode);
      const prExtras = document.querySelector('.puerto-rico-extras');

      expect(prExtras.hidden).to.eq(true);
    });

    it('shows extras if state is PR', () => {
      const forStateCode = 'PR';
      showOrHidePuertoRicoExtras(forStateCode);
      const prExtras = document.querySelector('.puerto-rico-extras');

      expect(prExtras.hidden).to.eq(false);
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
            <span data-state="CA" hidden>CA help text</span>
            <span data-state="TX" hidden>TX help text</span>
          </div>
        </div>
      `;
    });

    it('includes Texas specific hint text when Texas is selected', () => {
      const jurisdictionCode = 'TX';
      showOrHideJurisdictionExtras(jurisdictionCode);

      const allHintTexts = document.querySelectorAll('.jurisdiction-extras [data-state]');
      const texasText = document.querySelectorAll('.jurisdiction-extras [data-state=TX]');
      const hiddenText = [...allHintTexts].filter((text) => text.hidden);

      expect(texasText.length).to.eq(1);
      expect(texasText[0].hidden).to.eq(false);

      expect(hiddenText.length + texasText.length).to.eq(allHintTexts.length);
    });

    it('includes default hint text when no state is selected', () => {
      const jurisdictionCode = '';
      showOrHideJurisdictionExtras(jurisdictionCode);

      const allHintTexts = document.querySelectorAll('.jurisdiction-extras [data-state]');
      const defaultText = document.querySelectorAll('.jurisdiction-extras [data-state=default]');
      const hiddenText = [...allHintTexts].filter((text) => text.hidden);

      expect(defaultText.length).to.eq(1);
      expect(defaultText[0].hidden).to.eq(false);

      expect(hiddenText.length + defaultText.length).to.eq(allHintTexts.length);
    });

    it('includes default hint text when a state without a state specific hint is selected', () => {
      const jurisdictionCode = 'NY';
      showOrHideJurisdictionExtras(jurisdictionCode);

      const allHintTexts = document.querySelectorAll('.jurisdiction-extras [data-state]');
      const defaultText = document.querySelectorAll('.jurisdiction-extras [data-state=default]');
      const hiddenText = [...allHintTexts].filter((text) => text.hidden);

      expect(defaultText.length).to.eq(1);
      expect(defaultText[0].hidden).to.eq(false);

      expect(hiddenText.length + defaultText.length).to.eq(allHintTexts.length);
    });
  });
});
