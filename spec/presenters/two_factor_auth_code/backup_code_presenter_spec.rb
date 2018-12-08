require 'rails_helper'

describe TwoFactorAuthCode::BackupCodePresenter do
  include Rails.application.routes.url_helpers

  let(:presenter) do
    arguments = {}
    view = ActionController::Base.new.view_context
    TwoFactorAuthCode::BackupCodePresenter.new(data: arguments, view: view)
  end

  describe '#fallback_question' do
    it 'returns the fallback question' do
      expect(presenter.fallback_question).to eq \
        t('two_factor_authentication.backup_code_fallback.question')
    end
  end

  describe '#cancel_link' do
    it 'returns the link for cancellation' do
      expect(presenter.cancel_link).to eq \
        '/sign_out'
    end

    it 'returns a different link for cancellation if reauthn is true' do
      allow(presenter).to receive(:reauthn).and_return(true)
      expect(presenter.cancel_link).to eq \
        '/account'
    end
  end

  describe '#help_text' do
    it 'returns blank' do
      expect(presenter.help_text).to eq ''
    end
  end
end
