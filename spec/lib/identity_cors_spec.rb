require 'rails_helper'

RSpec.describe IdentityCors do
  before { Rails.cache.clear }
  after { Rails.cache.clear }

  describe '.allowed_redirect_uri?' do
    it 'returns true if the origin is a redirect_uri in a service provider' do
      create(:service_provider, redirect_uris: ['http://fake.example.com/authentication/result'])
      IdentityCors.allowed_redirect_uri?('http://fake.example.com')
    end

    it 'returns false if the origin is not a redirect_uri in a service provider' do
      IdentityCors.allowed_redirect_uri?('http://localhost:9999999999')
    end
  end
end
