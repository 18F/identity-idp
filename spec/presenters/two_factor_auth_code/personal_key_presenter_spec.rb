require 'rails_helper'

RSpec.describe TwoFactorAuthCode::PersonalKeyPresenter do
  include Rails.application.routes.url_helpers

  let(:presenter) do
    TwoFactorAuthCode::PersonalKeyPresenter.new
  end

  describe '#fallback_question' do
    it 'returns the fallback question' do
      expect(presenter.fallback_question).to eq \
        t('two_factor_authentication.personal_key_fallback.question')
    end
  end
end
