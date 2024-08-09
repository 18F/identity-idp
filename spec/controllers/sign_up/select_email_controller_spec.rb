require 'rails_helper'

RSpec.describe SignUp::SelectEmailController do
  describe '#create' do
    let(:email) { 'michael.motorist@email.com' }
    let(:email2) { 'michael.motorist2@email.com' }
    let(:email3) { 'david.motorist@email.com' }
    let(:user) { create(:user) }

    before do
      user.email_addresses = []
      user.email_addresses.create(email: email, confirmed_at: Time.zone.now)
      user.email_addresses.create(email: email2, confirmed_at: Time.zone.now)
    end

    it 'updates selected email address' do
      post :create, params: { selected_email_id: email2 }

      expect(user.email_addresses.last.email).
        to include('michael.motorist2@email.com')
    end

    context 'with a corrupted email selected_email_id form' do
      render_views
      it 'rejects email not belonging to the user' do
        stub_sign_in(user)
        post :create, params: { selected_email_id: email3 }

        expect(user.email_addresses.last.email).
          to include('michael.motorist2@email.com')

        expect(response).to redirect_to(sign_up_select_email_path)
      end
    end
  end
end
