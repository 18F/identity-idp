require 'rails_helper'

feature 'SAML RelayState' do
  include SamlAuthHelper

  context 'when RelayState is passed in authn request' do
    let(:user) { create(:user, :signed_up) }
    let(:relay_state_value) { '8431d690-2ed1-11eb-adc1-0242ac120002' }
    let(:params) { { RelayState: relay_state_value } }

    it 'returns RelayState on GET authn request' do
      get_saml_authn_request(sp1_saml_settings, params)

      login_and_confirm_sp(user)

      expect(find_field('SAMLResponse', type: :hidden).value).not_to be_blank
      expect(find_field('RelayState', type: :hidden).value).to eq(relay_state_value)
    end

    it 'returns RelayState on POST authn request' do
      post_saml_authn_request(sp1_saml_settings, params)

      login_and_confirm_sp(user)

      expect(find_field('SAMLResponse', type: :hidden).value).not_to be_blank
      expect(find_field('RelayState', type: :hidden).value).to eq(relay_state_value)
    end
  end

  context 'when RelayState is NOT passed in authn request' do
    let(:user) { create(:user, :signed_up) }

    it 'does not return RelayState on GET authn request' do
      get_saml_authn_request(sp1_saml_settings)

      login_and_confirm_sp(user)

      expect(find_field('SAMLResponse', type: :hidden).value).not_to be_blank
      expect do
        find_field('RelayState', type: :hidden)
      end.to raise_error(/Unable to find field "RelayState"/)
    end

    it 'does not return RelayState on POST authn request' do
      post_saml_authn_request(sp1_saml_settings)

      login_and_confirm_sp(user)

      expect(find_field('SAMLResponse', type: :hidden).value).not_to be_blank
      expect do
        find_field('RelayState', type: :hidden)
      end.to raise_error(/Unable to find field "RelayState"/)
    end
  end
end
