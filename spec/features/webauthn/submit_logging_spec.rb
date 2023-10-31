require 'rails_helper'

RSpec.feature 'webauthn sign in' do
  include WebAuthnHelper

  before do
    allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
  end

  let!(:user) { sign_up_and_set_password }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:general_error) do
    t(
      'two_factor_authentication.webauthn_error.connect_html',
      link_html: t('two_factor_authentication.webauthn_error.additional_methods_link'),
    )
  end

  context 'platform authenticator' do
    it 'maintains correct platform attachment content if cancelled', :js do
      select_2fa_option('webauthn_platform', visible: :all)

      expect(current_path).to eq webauthn_setup_path

      mock_webauthn_setup_challenge
      fill_in_nickname_and_click_continue
      mock_submit_without_pressing_button_on_hardware_key_on_setup
      expect(fake_analytics).to have_logged_event(
        :webauthn_setup_submitted,
        hash_including(success: false),
      )
    end
  end
end
