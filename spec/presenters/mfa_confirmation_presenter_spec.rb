require 'rails_helper'

RSpec.describe MfaConfirmationPresenter do
  let(:user) { create(:user, :with_phone) }
  let(:mfa_context) { MfaContext.new(user) }
  let(:presenter) { described_class.new(mfa_context) }

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

  describe '#show_skip_link?' do
    it 'returns true' do
      expect(presenter.show_skip_link?).to eq(true)
    end

    context 'when the user only has enabled mfa webauthn platform' do
      let(:user) { create(:user, :with_webauthn_platform) }

      it 'returns false' do
        expect(presenter.show_skip_link?).to eq(false)
      end
    end
  end
end
