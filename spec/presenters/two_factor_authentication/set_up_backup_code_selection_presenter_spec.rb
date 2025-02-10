require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpBackupCodeSelectionPresenter do
  let(:user) { create(:user) }
  let(:presenter) { described_class.new(user:) }

  describe '#phishing_resistant?' do
    subject(:phishing_resistant) { presenter.phishing_resistant? }

    it { expect(phishing_resistant).to eq(false) }
  end
end
