require 'rails_helper'

RSpec.describe MarketingSite do
  describe '.privacy_url' do
    it 'points to the privacy page' do
      expect(MarketingSite.privacy_url).to eq('https://login.gov/policy')
    end
  end

  describe '.contact_url' do
    it 'points to the contact page' do
      expect(MarketingSite.contact_url).to eq('https://login.gov/contact')
    end
  end

  describe '.help_url' do
    it 'points to the help page' do
      expect(MarketingSite.help_url).to eq('https://login.gov/help')
    end
  end
end
