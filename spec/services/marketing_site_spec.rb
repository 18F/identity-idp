require 'rails_helper'

RSpec.describe MarketingSite do
  describe '.base_url' do
    it 'points to the base URL' do
      expect(MarketingSite.base_url).to eq('https://www.login.gov/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the base URL with the locale appended' do
        expect(MarketingSite.base_url).to eq('https://www.login.gov/es/')
      end
    end
  end

  describe '.privacy_url' do
    it 'points to the privacy page' do
      expect(MarketingSite.privacy_url).to eq('https://www.login.gov/policy')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the privacy page with the locale appended' do
        expect(MarketingSite.privacy_url).to eq('https://www.login.gov/es/policy')
      end
    end
  end

  describe '.contact_url' do
    it 'points to the contact page' do
      expect(MarketingSite.contact_url).to eq('https://www.login.gov/contact')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the contact page with the locale appended' do
        expect(MarketingSite.contact_url).to eq('https://www.login.gov/es/contact')
      end
    end
  end

  describe '.help_url' do
    it 'points to the help page' do
      expect(MarketingSite.help_url).to eq('https://www.login.gov/help')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the help page with the locale appended' do
        expect(MarketingSite.help_url).to eq('https://www.login.gov/es/help')
      end
    end
  end

  describe '.help_authentication_app_url' do
    it 'points to the authentication app section of the help page' do
      expect(MarketingSite.help_authentication_app_url).to eq(
        'https://www.login.gov/help/signing-in/what-is-an-authentication-app/'
      )
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the authentication app section of the help page with the locale appended' do
        expect(MarketingSite.help_authentication_app_url).to eq(
          'https://www.login.gov/es/help/signing-in/what-is-an-authentication-app/'
        )
      end
    end
  end
end
