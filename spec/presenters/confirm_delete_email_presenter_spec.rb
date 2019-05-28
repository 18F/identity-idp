require 'rails_helper'

describe ConfirmDeleteEmailPresenter do
  let(:user) { create(:user, :signed_up, email: 'email@example.com') }
  let(:email_address) { user.email_addresses.first }
  let(:presenter) { described_class.new(user, email_address) }

  describe '#confirm_delete_message' do
    it 'supplies a message for confirm delete page' do
      expect(presenter.confirm_delete_message).
        to eq(t('email_addresses.delete.confirm', email: email_address.email))
    end
  end
end
