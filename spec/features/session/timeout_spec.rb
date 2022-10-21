require 'rails_helper'

feature 'Session Timeout' do
  context 'when SP info no longer in session but request_id params exists' do
    it 'preserves the branded experience' do
      issuer = 'http://localhost:3000'
      sp_request = ServiceProviderRequestProxy.create(
        issuer: issuer,
        url: 'foo',
        uuid: '123',
        ial: '1',
      )
      sp = ServiceProvider.find_by(issuer: issuer)

      visit root_url(request_id: sp_request.uuid)

      expect(page).to have_link sp.friendly_name
      expect(page).to have_css('img[src*=sp-logos]')
    end
  end

  context 'when SP info is in session' do
    it 'displays the branded experience' do
      issuer = 'http://localhost:3000'
      sp = ServiceProvider.find_by(issuer: issuer)
      sp_session = { issuer: issuer, request_url: 'http://localhost:3000/api/saml/auth' }
      page.set_rack_session(sp: sp_session)
      visit root_path

      expect(page).to have_link sp.friendly_name
      expect(page).to have_css('img[src*=sp-logos]')
    end
  end

  context 'when total session duration expires' do
    let(:fake_analytics) { FakeAnalytics.new }
    before do
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    end

    it 'signs out the user and displays the timeout message' do
      sign_in_and_2fa_user

      timeout_in_minutes = IdentityConfig.store.session_total_duration_timeout_in_minutes.to_i
      travel_to((timeout_in_minutes + 1).minutes.from_now) do
        visit account_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_content(t('devise.failure.timeout'))
        expect(fake_analytics).to have_logged_event('User Maximum Session Length Exceeded', {})
      end
    end
  end
end
