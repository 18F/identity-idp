require 'rails_helper'

# Covers app/services/piv_cac/check_config.rb, which raises an error if the
# piv_cac_verify_token_url is not configured with https in production environments.
RSpec.describe PivCac::CheckConfig do
  let(:is_production) { false }
  let(:url) { 'http://non-secure.example.com/' }

  before do
    allow(Rails.env).to receive(:production?).and_return(is_production)
    allow(IdentityConfig.store).to receive(:piv_cac_verify_token_url).and_return(url)
  end

  context 'non-production environments' do
    it 'does not raise an error' do
      expect { PivCac::CheckConfig.call }.not_to raise_error
    end
  end

  context 'production environments' do
    let(:is_production) { true }

    context 'non-https config' do
      it 'does raise an error' do
        expect { PivCac::CheckConfig.call }.
          to raise_error(RuntimeError, "piv_cac_verify_token_url configured without SSL: #{url}")
      end
    end

    context 'https config' do
      let(:url) { 'https://secure.example.com' }

      it 'does not raise an error' do
        expect { PivCac::CheckConfig.call }.not_to raise_error
      end
    end
  end
end
