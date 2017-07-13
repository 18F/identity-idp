require 'rails_helper'

RSpec.describe MarketingSite do
  describe '.base_url' do
    it 'points to the base URL' do
      expect(MarketingSite.base_url).to eq('https://www.login.gov')
    end
  end

  describe '.privacy_url' do
    it 'points to the privacy page' do
      expect(MarketingSite.privacy_url).to eq('https://www.login.gov/policy')
    end
  end

  describe '.contact_url' do
    it 'points to the contact page' do
      expect(MarketingSite.contact_url).to eq('https://www.login.gov/contact')
    end
  end

  describe '.help_url' do
    it 'points to the help page' do
      expect(MarketingSite.help_url).to eq('https://www.login.gov/help')
    end
  end

  describe '.help_authenticator_app_url' do
    it 'points to the authenticator app section of the help page' do
      expect(MarketingSite.help_authenticator_app_url).to eq(
        'https://www.login.gov/help/signing-in/what-is-an-authenticator-app/'
      )
    end
  end
end
