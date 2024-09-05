require 'rails_helper'

RSpec.describe SignUp::SelectEmailController do
  let(:user) { create(:user) }
  let(:sp) { create(:service_provider) }

  before do
    stub_sign_in(user)
    allow(controller).to receive(:current_sp).and_return(sp)
    allow(controller).to receive(:needs_completion_screen_reason).and_return(:new_attributes)
  end

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

  describe '#show' do
    subject(:response) { get :show }

    it 'assigns view variables' do
      response

      expect(assigns(:sp_name)).to be_kind_of(String)
      expect(assigns(:user_emails)).to all be_kind_of(EmailAddress)
      expect(assigns(:last_sign_in_email_address)).to be_kind_of(String)
      expect(assigns(:select_email_form)).to be_kind_of(SelectEmailForm)
    end

    context 'with selected email to share feature disabled' do
      before do
        allow(IdentityConfig.store).to receive(:feature_select_email_to_share_enabled).
          and_return(false)
      end

      it 'renders 404' do
        expect(response).to be_not_found
      end
    end
  end

  describe '#create' do
    let(:email) { 'michael.motorist@email.com' }
    let(:email2) { 'michael.motorist2@email.com' }
    let(:email3) { 'david.motorist@email.com' }
    let(:params) { { selected_email_id: email2 } }

    subject(:response) { post :create, params: params }

    before do
      create(:email_address, user:, email: email)
      create(:email_address, user:, email: email2)
    end

    it 'updates selected email address' do
      response

      expect(user.email_addresses.last.email).
        to include('michael.motorist2@email.com')
    end

    context 'with a corrupted email selected_email_id form' do
      let(:params) { { selected_email_id: email3 } }

      it 'rejects email not belonging to the user' do
        expect(response).to redirect_to(sign_up_select_email_path)
        expect(user.email_addresses.last.email).
          to include('michael.motorist2@email.com')
      end
    end

    context 'with selected email to share feature disabled' do
      before do
        allow(IdentityConfig.store).to receive(:feature_select_email_to_share_enabled).
          and_return(false)
      end

      it 'renders 404' do
        expect(response).to be_not_found
      end
    end
  end
end
