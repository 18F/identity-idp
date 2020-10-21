require 'rails_helper'

feature 'Session Timeout' do
  context 'when SP info no longer in session but request_id params exists' do
    it 'preserves the branded experience' do
      issuer = 'http://localhost:3000'
      sp_request = ServiceProviderRequestProxy.create(issuer: issuer,
                                                      url: 'foo',
                                                      uuid: '123',
                                                      ial: '1')
      sp = ServiceProvider.from_issuer(issuer)

      visit root_url(request_id: sp_request.uuid)

      expect(page).to have_link sp.friendly_name
      expect(page).to have_css('img[src*=sp-logos]')
    end
  end

  context 'when SP info is in session' do
    it 'displays the branded experience' do
      issuer = 'http://localhost:3000'
      sp = ServiceProvider.from_issuer(issuer)
      sp_session = { issuer: issuer, request_url: 'http://localhost:3000/api/saml/auth' }
      page.set_rack_session(sp: sp_session)
      visit root_path

      expect(page).to have_link sp.friendly_name
      expect(page).to have_css('img[src*=sp-logos]')
    end
  end

  context 'allows extending session', js: true do
    let(:user) { create(:user, :signed_up, created_at: Time.zone.now - 100.days) }

    before do
      allow(Figaro.env).
        to receive(:session_check_frequency).and_return('1')
      allow(Figaro.env).
        to receive(:session_check_delay).and_return('0')
      allow(Figaro.env).
        to receive(:session_timeout_warning_seconds).and_return('1000')
      allow(Figaro.env).
        to receive(:session_timeout_in_minutes).and_return('1')
    end

    it 'shows warning with button to extend' do
      sign_in_and_2fa_user(user)

      visit account_path
      click_button(t('notices.timeout_warning.signed_in.continue'))
    end
  end
end
