require 'rails_helper'

RSpec.describe UpdatePasswordPresenter do
  let(:view) { double(:view, link_to: '') }
  let(:user) { create(:user) }
  let(:required_password_change) { false }
  let(:presenter) { described_class.new(user: user, required_password_change:) }

  describe '#submit_text' do
    context 'required_password_change set to true' do
      let(:required_password_change) { true }
      it 'returns change password text' do
        expect(presenter.submit_text).to eq t('forms.passwords.edit.buttons.submit')
      end
    end

    context 'required_password_change is set to false' do
      it 'returns update text' do
        expect(presenter.submit_text).to eq t('forms.buttons.submit.update')
      end
    end
  end

  describe '#forbidden_passwords' do
    it 'returns forbidden passwords for user' do
      expect(presenter.forbidden_passwords).to include(user.email_addresses.first.email)
    end
  end
end
