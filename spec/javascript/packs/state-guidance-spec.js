import { showOrHidePuertoRicoExtras } from '../../../app/javascript/packs/state-guidance';

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
});
