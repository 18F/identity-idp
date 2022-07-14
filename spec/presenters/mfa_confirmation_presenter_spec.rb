require 'rails_helper'

describe MfaConfirmationPresenter do
  let(:user) { create(:user, :with_phone) }
  let(:presenter) { described_class.new(user) }

  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
  end

  describe '#heading?' do
    it 'supplies a message' do
      expect(presenter.heading).
        to eq(t('titles.mfa_setup.suggest_second_mfa'))
    end
  end

  describe '#info?' do
    it 'supplies a message' do
      expect(presenter.info).
        to eq(
          t('mfa.account_info'),
        )
    end
  end

  describe '#button?' do
    it 'supplies a message' do
      expect(presenter.button).
        to eq(t('mfa.add'))
    end
  end
end
