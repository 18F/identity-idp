require 'rails_helper'

RSpec.describe MfaConfirmationPresenter do
  let(:user) { create(:user, :with_phone) }
  let(:presenter) do
    described_class.new
  end

  describe '#heading?' do
    it 'supplies a message' do
      expect(presenter.heading).
        to eq(t('titles.mfa_setup.suggest_second_mfa'))
    end

    context 'after face or touch unlock setup' do
      let(:webauthn_platform_set_up_successful) { true }
      let(:presenter) do
        described_class.new(
          webauthn_platform_set_up_successful: webauthn_platform_set_up_successful,
        )
      end

      it 'shows the correct heading' do
        expect(presenter.heading).
          to eq(t('titles.mfa_setup.face_touch_unlock_confirmation'))
      end
    end
  end

  describe '#info?' do
    it 'supplies a message' do
      expect(presenter.info).
        to eq(
          t('mfa.account_info'),
        )
    end

    context 'after face or touch unlock setup' do
      let(:webauthn_platform_set_up_successful) { true }
      let(:presenter) do
        described_class.new(
          webauthn_platform_set_up_successful: webauthn_platform_set_up_successful,
        )
      end

      it 'shows the correct heading' do
        expect(presenter.info).
          to eq(t('mfa.webauthn_platform_message'))
      end
    end
  end

  describe '#button?' do
    it 'supplies a message' do
      expect(presenter.button).
        to eq(t('mfa.add'))
    end
  end

  describe '#show_skip_additional_mfa_link?' do
    it 'returns true' do
      expect(presenter.show_skip_additional_mfa_link?).to eq(true)
    end

    context 'when show_skip_additional_mfa_link is false' do
      let(:show_skip_additional_mfa_link) { false }
      let(:presenter) do
        described_class.new(
          show_skip_additional_mfa_link: show_skip_additional_mfa_link,
        )
      end

      it 'returns false' do
        expect(presenter.show_skip_additional_mfa_link?).to eq(false)
      end
    end
  end
end
