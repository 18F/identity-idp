require 'rails_helper'

describe MfaConfirmationPresenter do
  let(:user) { create(:user, :with_phone) }
  let(:presenter) { described_class.new(user) }

  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
  end

  describe '#enforce_second_mfa?' do
    it 'checks the multi mfa feature flag and whether the user has a non restriced mfa' do
      expect(presenter.enforce_second_mfa?).to be true
    end
  end

  describe '#heading?' do
    it 'supplies a message depending on #enforce_second_mfa?' do
      expect(presenter.heading).
        to eq(t('mfa.non_restricted.heading'))
    end
  end

  # describe '#info?' do
  #   it 'supplies a message depending on #enforce_second_mfa?' do
  #     expect(presenter.confirm_delete_message).
  #       to eq(t('email_addresses.delete.confirm', email: email_address.email))
  #   end
  # end

  # describe '#button?' do
  #   it 'supplies a message depending on #enforce_second_mfa?' do
  #     expect(presenter.confirm_delete_message).
  #       to eq(t('email_addresses.delete.confirm', email: email_address.email))
  #   end
  # end
end
