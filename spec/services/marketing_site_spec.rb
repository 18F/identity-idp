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

  describe '.help_idv_supported_documents_url' do
    it 'points to the authentication app section of the help page' do
      expect(MarketingSite.help_idv_supported_documents_url).to eq(
        'https://www.login.gov/help/verify-your-identity/accepted-state-issued-identification/',
      )
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the authentication app section of the help page with the locale appended' do
        expect(MarketingSite.help_idv_supported_documents_url).to eq(
          'https://www.login.gov/es/help/verify-your-identity/accepted-state-issued-identification/',
        )
      end
    end
  end

  describe '.help_idv_verify_by_mail_url' do
    it 'points to the authentication app section of the help page' do
      expect(MarketingSite.help_idv_verify_by_mail_url).to eq(
        'https://www.login.gov/help/verify-your-identity/verify-your-address-by-mail/',
      )
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the authentication app section of the help page with the locale appended' do
        expect(MarketingSite.help_idv_verify_by_mail_url).to eq(
          'https://www.login.gov/es/help/verify-your-identity/verify-your-address-by-mail/',
        )
      end
    end
  end

  describe '.help_idv_verify_by_phone_url' do
    it 'points to the authentication app section of the help page' do
      expect(MarketingSite.help_idv_verify_by_phone_url).to eq(
        'https://www.login.gov/help/verify-your-identity/phone-number-and-phone-plan-in-your-name/',
      )
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the authentication app section of the help page with the locale appended' do
        expect(MarketingSite.help_idv_verify_by_phone_url).to eq(
          'https://www.login.gov/es/help/verify-your-identity/phone-number-and-phone-plan-in-your-name/',
        )
      end
    end
  end

  describe '.help_document_capture_tips_url' do
    it 'points to the authentication app section of the help page' do
      expect(MarketingSite.help_document_capture_tips_url).to eq(
        'https://www.login.gov/help/verify-your-identity/how-to-add-images-of-your-state-issued-id/',
      )
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the authentication app section of the help page with the locale appended' do
        expect(MarketingSite.help_document_capture_tips_url).to eq(
          'https://www.login.gov/es/help/verify-your-identity/how-to-add-images-of-your-state-issued-id/',
        )
      end
    end
  end
end
