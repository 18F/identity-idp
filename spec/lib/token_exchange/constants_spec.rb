require 'rails_helper'

RSpec.describe TokenExchange::Constants do
  describe 'RFC URNs' do
    it 'uses the RFC 8693 token exchange grant type' do
      expect(described_class::GRANT_TYPE).to eq(
        'urn:ietf:params:oauth:grant-type:token-exchange',
      )
    end

    it 'uses the RFC 8693 access token type' do
      expect(described_class::ACCESS_TOKEN_TYPE).to eq(
        'urn:ietf:params:oauth:token-type:access_token',
      )
    end

    it 'uses the RFC 7523 private_key_jwt client assertion type' do
      expect(described_class::CLIENT_ASSERTION_TYPE).to eq(
        'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
      )
    end
  end

  describe 'scope constants' do
    it 'defines the base delegated access scope' do
      expect(described_class::SCOPE).to eq('token_exchange')
    end

    it 'defines the audience-qualified scope prefix' do
      expect(described_class::SCOPE_PREFIX).to eq('token_exchange:')
    end
  end

  describe '.in_scope?' do
    it 'matches the base scope' do
      expect(described_class.in_scope?('token_exchange')).to eq(true)
    end

    it 'matches any audience-qualified scope' do
      expect(described_class.in_scope?('token_exchange:passport')).to eq(true)
      expect(described_class.in_scope?('token_exchange:benefits')).to eq(true)
    end

    it 'does not match other scopes' do
      expect(described_class.in_scope?('openid')).to eq(false)
      expect(described_class.in_scope?('token_exchange_passport')).to eq(false)
      expect(described_class.in_scope?(nil)).to eq(false)
    end
  end
end
