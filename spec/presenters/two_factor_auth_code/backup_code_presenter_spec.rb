require 'rails_helper'

RSpec.describe TwoFactorAuthCode::BackupCodePresenter do
  include Rails.application.routes.url_helpers

  let(:presenter) do
    arguments = {}
    view = ActionController::Base.new.view_context
    TwoFactorAuthCode::BackupCodePresenter.new(data: arguments, view:, service_provider: nil)
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
end
