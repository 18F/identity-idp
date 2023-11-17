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
          <div class="jurisdiction-extras"></div>
        </div>
      `;
    });

    it('includes Texas specific hint text when Texas is selected', () => {
      const jurisdictionCode = 'TX';
      showOrHideJurisdictionExtras(jurisdictionCode);
      const elementInnerHtml = document.querySelector('.jurisdiction-extras')?.textContent;

      expect(elementInnerHtml).to.eq('in_person_proofing.form.state_id.state_id_number_texas_hint');
    });

    it('includes default hint text when no state is selected', () => {
      const jurisdictionCode = ' ';
      showOrHideJurisdictionExtras(jurisdictionCode);
      const elementInnerHtml = document.querySelector('.jurisdiction-extras')?.textContent;

      expect(elementInnerHtml).to.eq('in_person_proofing.form.state_id.state_id_number_hint');
    });

    it('includes default hint text when a state without a state specific hint is selected', () => {
      const jurisdictionCode = 'NY';
      showOrHideJurisdictionExtras(jurisdictionCode);
      const elementInnerHtml = document.querySelector('.jurisdiction-extras')?.textContent;

      expect(elementInnerHtml).to.eq('in_person_proofing.form.state_id.state_id_number_hint');
    });
  });
});
