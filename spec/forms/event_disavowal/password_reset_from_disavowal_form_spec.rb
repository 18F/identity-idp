require 'rails_helper'

RSpec.describe EventDisavowal::PasswordResetFromDisavowalForm, type: :model do
  let(:user) { create(:user, password: 'salty pickles') }
  let(:new_password) { 'saltier pickles' }
  let(:event) { create(:event, user: user) }

  subject { described_class.new(event) }

  it_behaves_like 'password validation'

  context 'with a valid password' do
    it 'resets the users password' do
      subject.submit(password: new_password)

      expect(user.reload.valid_password?(new_password)).to eq(true)
    end

    it 'deletes the site key root, which cannot be re-wrapped without the old password' do
      allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(true)
      create_site_key_root(user, password: 'salty pickles')

      subject.submit(password: new_password)

      expect(user.reload.site_key_root).to be_nil
    end
  end

  context 'with an invalid password' do
    let(:new_password) { 'too short' }

    it 'does not reset the users passowrd' do
      subject.submit(password: new_password)

      expect(user.reload.valid_password?(new_password)).to eq(false)
    end
  end
end
