require 'rails_helper'

describe OmniauthCallbackPolicy do
  subject { OmniauthCallbackPolicy.new(current_user, :omniauth_callback) }

  context 'FeatureManagement.allow_third_party_auth? is true' do
    let(:current_user) { build_stubbed :user }
    before do
      allow(FeatureManagement).to receive(:allow_third_party_auth?).
        and_return(true)
    end

    it { is_expected.to permit_action(:saml) }
  end

  context 'FeatureManagement.allow_third_party_auth? is false' do
    let(:current_user) { build_stubbed :user }
    before do
      allow(FeatureManagement).to receive(:allow_third_party_auth?).
        and_return(false)
    end

    it { is_expected.to_not permit_action(:saml) }
  end
end
