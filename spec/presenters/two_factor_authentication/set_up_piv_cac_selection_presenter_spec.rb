require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpPivCacSelectionPresenter do
  let(:user) { create(:user) }
  let!(:federal_domain) { create(:federal_email_domain, name: 'gsa.gov') }
  subject(:presenter) { described_class.new(user:) }

  describe '#type' do
    it 'returns piv_cac' do
      expect(presenter.type).to eq :piv_cac
    end
  end

  describe '#mfa_configruation' do
    subject(:description) { presenter.mfa_configuration_description }

    context 'user has not configured piv/cac' do
      let(:user) { create(:user) }

      it 'returns an empty string' do
        expect(description).to eq('')
      end
    end

    context 'user has configured piv/cac' do
      let(:user) { create(:user, :with_piv_or_cac) }

      it 'returns the translated string for added' do
        expect(description).to eq(
          t('two_factor_authentication.two_factor_choice_options.no_count_configuration_added'),
        )
      end
    end
  end

  describe '#recommended?' do
    subject(:recommended) { presenter.recommended? }

    context 'with a confirmed email address ending in anything other than .gov or .mil' do
      let(:user) { create(:user, email: 'example@example.com') }

      it { expect(recommended).to eq(false) }
    end

    context 'with a confirmed email address ending in .gov or .mil' do
      let(:user) { create(:user, email: 'example@gsa.gov') }

      it { expect(recommended).to eq(true) }
    end
  end

  describe '#phishing_resistant?' do
    subject(:phishing_resistant) { presenter.phishing_resistant? }

    it { expect(phishing_resistant).to eq(true) }
  end

  describe '#desktop_only?' do
    subject(:desktop_only) { presenter.desktop_only? }

    it { expect(desktop_only).to eq(true) }
  end
end
