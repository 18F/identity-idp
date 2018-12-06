require 'rspec'

describe 'BackupCodePresenter' do
  let(:presenter) do
    TwoFactorAuthCode::BackupCodePresenter.new
  end

  describe '#help_text'
  it 'should return help text' do
    expect(presenter.help_text).to eq ''
  end

  describe '#fallback_question' do
    it 'returns the fallback question' do
      expect(presenter.fallback_question).to eq \
        t('two_factor_authentication.backup_code_fallback.question')
    end
  end
end


#module TwoFactorAuthCode
#  class BackupCodePresenter < TwoFactorAuthCode::GenericDeliveryPresenter
#    include Rails.application.routes.url_helpers
#    include ActionView::Helpers::TranslationHelper
#
#    attr_reader :credential_ids
#
#    def help_text
#      ''
#    end
#
#    def cancel_link
#      locale = LinkLocaleResolver.locale
#      if reauthn
#        account_path(locale: locale)
#      else
#        sign_out_path(locale: locale)
#      end
#    end
#
#    def fallback_question
#      t('two_factor_authentication.backup_code_fallback.question')
#    end
#  end
#end

