require 'rails_helper'

RSpec.describe SignUp::SelectEmailController do
  describe 'before_actions' do
    it 'requires the user be logged in and authenticated' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'requires the user be in the completions flow' do
      expect(subject).to have_actions(
        :before,
        :verify_needs_completions_screen,
      )
    end
  end

  describe '#create' do
    let(:email) { 'michael.motorist@email.com' }
    let(:email2) { 'michael.motorist2@email.com' }
    let(:email3) { 'david.motorist@email.com' }
    let(:user) { create(:user) }

    before do
      user.email_addresses = []
      create(:email_address, user:, email: email)
      create(:email_address, user:, email: email2)
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
        allow(controller).to receive(:needs_completion_screen_reason).and_return(true)
        post :create, params: { selected_email_id: email3 }

        expect(user.email_addresses.last.email).
          to include('michael.motorist2@email.com')

        expect(response).to redirect_to(sign_up_select_email_path)
      end
    end
  end
end
