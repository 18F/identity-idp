require 'rails_helper'

RSpec.describe SignUp::SelectEmailController do
  let(:user) { create(:user, :with_multiple_emails) }
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

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        :sp_select_email_visited,
        needs_completion_screen_reason: :new_attributes,
      )
    end

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
    let(:selected_email) { user.confirmed_email_addresses.sample }
    let(:params) { { select_email_form: { selected_email_id: selected_email.id } } }

    subject(:response) { post :create, params: params }

    it 'updates selected email address' do
      response

      expect(controller.user_session[:selected_email_id]).to eq(selected_email.id.to_s)
    end

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(:sp_select_email_submitted, success: true)
    end

    context 'with a corrupted email selected_email_id form' do
      let(:other_user) { create(:user) }
      let(:selected_email) { other_user.confirmed_email_addresses.sample }

      it 'rejects email not belonging to the user' do
        expect(response).to redirect_to(sign_up_select_email_path)
        expect(controller.user_session[:selected_email_id]).to eq(nil)
      end

      it 'logs analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :sp_select_email_submitted,
          success: false,
          error_details: { selected_email_id: { not_found: true } },
        )
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
