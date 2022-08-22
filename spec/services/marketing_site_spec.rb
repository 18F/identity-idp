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

  describe '.security_and_privacy_practices_url' do
    it 'points to the privacy page' do
      expect(MarketingSite.security_and_privacy_practices_url).
        to eq('https://www.login.gov/policy')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the privacy page with the locale appended' do
        expect(MarketingSite.security_and_privacy_practices_url).
          to eq('https://www.login.gov/es/policy')
      end
    end
  end

  describe '.security_and_privacy_how_it_works_url' do
    it 'points to the privacy page' do
      expect(MarketingSite.security_and_privacy_how_it_works_url).
        to eq('https://www.login.gov/policy/how-does-it-work/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the privacy page with the locale appended' do
        expect(MarketingSite.security_and_privacy_how_it_works_url).
          to eq('https://www.login.gov/es/policy/how-does-it-work/')
      end
    end
  end

  describe '.rules_of_use_url' do
    it 'points to the rules of use page' do
      expect(MarketingSite.rules_of_use_url).
        to eq('https://www.login.gov/policy/rules-of-use/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the rules of use page with the locale appended' do
        expect(MarketingSite.rules_of_use_url).
          to eq('https://www.login.gov/es/policy/rules-of-use/')
      end
    end
  end

  describe '.messaging_practices_url' do
    it 'points to messaging practices section of the privacy page' do
      expect(MarketingSite.messaging_practices_url).
        to eq('https://www.login.gov/policy/messaging-terms-and-conditions/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the privacy page section with the locale appended' do
        expect(MarketingSite.messaging_practices_url).
          to eq('https://www.login.gov/es/policy/messaging-terms-and-conditions/')
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
        'https://www.login.gov/help/creating-an-account/authentication-application/',
      )
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the authentication app section of the help page with the locale appended' do
        expect(MarketingSite.help_authentication_app_url).to eq(
          'https://www.login.gov/es/help/creating-an-account/authentication-application/',
        )
      end
    end
  end

  describe '.help_center_article_url' do
    let(:category) {}
    let(:article) {}
    let(:result) { MarketingSite.help_center_article_url(category: category, article: article) }

    context 'with invalid article' do
      let(:category) { 'foo' }
      let(:article) { 'bar' }

      it 'raises ArgumentError' do
        expect { result }.to raise_error ArgumentError
      end
    end

    context 'with valid article' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }

      it 'returns article URL' do
        expect(result).to eq(
          'https://www.login.gov/help/verify-your-identity/accepted-state-issued-identification/',
        )
      end
    end
  end

  describe '.valid_help_center_article?' do
    let(:category) {}
    let(:article) {}
    let(:result) { MarketingSite.valid_help_center_article?(category: category, article: article) }

    context 'with invalid article' do
      let(:category) { 'foo' }
      let(:article) { 'bar' }

      it { expect(result).to eq(false) }
    end

    context 'with valid article' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }

      it { expect(result).to eq(true) }
    end
  end
end
