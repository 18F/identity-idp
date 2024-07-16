require 'rails_helper'

RSpec.describe SignUp::SelectEmailController do
  describe '#create' do
    let(:email) { 'michael.motorist@email.com' }
    let(:email2) { 'michael.motorist2@email.com' }
    let(:user) { create(:user) }

    before do
      user.email_addresses = []
      user.email_addresses.create(email: email, confirmed_at: Time.zone.now)
      user.email_addresses.create(email: email2, confirmed_at: Time.zone.now)
    end

    it 'updates selected email address' do
      post :create, params: { selection: email2 }

      expect(user.email_addresses.last_sign_in_email_address.email).
        to include('michael.motorist2@email.com')
    end
  end
end
