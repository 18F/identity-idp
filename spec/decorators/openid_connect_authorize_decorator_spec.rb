require 'rails_helper'

RSpec.describe OpenidConnectAuthorizeDecorator do
  subject(:decorator) do
    OpenidConnectAuthorizeDecorator.new(scopes: scopes, service_provider: service_provider)
  end

  let(:scopes) { %w(openid email profile) }
  let(:service_provider) { ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:test') }

  describe '#name' do
    it 'is the friendly name' do
      expect(decorator.name).to eq('Example iOS App')
    end
  end

  describe '#requested_attributes' do
    it 'is the openid claims for the scopes requested' do
      expect(decorator.requested_attributes).
        to match_array(%w(email given_name family_name birthdate))
    end
  end

  describe '#logo' do
    it 'is the service provider logo' do
      expect(decorator.logo).to eq('generic.svg')
    end
  end
end
