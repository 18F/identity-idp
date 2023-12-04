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

  describe '#webauthn_platform_set_up_successful?' do
    it 'returns false' do
      expect(presenter.webauthn_platform_set_up_successful?).to eq(false)
    end

    context 'when f/t unlock setup is successful' do
      let(:webauthn_platform_set_up_successful) { true }
      let(:expected_heading) { t('titles.mfa_setup.face_touch_unlock_confirmation') }
      let(:expected_info) { I18n.t('mfa.webauthn_platform_message') }
      let(:presenter) do
        described_class.new(
          webauthn_platform_set_up_successful: webauthn_platform_set_up_successful,
        )
      end

      it 'returns true' do
        expect(presenter.webauthn_platform_set_up_successful?).to eq(true)
      end

      it 'shows the correct heading' do
        expect(presenter.heading).to eq expected_heading
      end

      it 'shows the correct content' do
        expect(presenter.info).to eq expected_info
      end
    end
  end
end
