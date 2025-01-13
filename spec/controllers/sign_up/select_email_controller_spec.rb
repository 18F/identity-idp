require 'rails_helper'

RSpec.describe SignUp::SelectEmailController do
  let(:user) { create(:user, :with_multiple_emails) }
  let(:service_provider_attribute_bundle) { %w[email] }
  let(:sp) do
    create(
      :service_provider,
      attribute_bundle: service_provider_attribute_bundle,
    )
  end

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
      expect(assigns(:can_add_email)).to eq(true)
    end

    context 'with selected email to share feature disabled' do
      before do
        allow(IdentityConfig.store).to receive(:feature_select_email_to_share_enabled)
          .and_return(false)
      end

      it 'renders 404' do
        expect(response).to be_not_found
      end
    end

    context 'when users has max number of emails' do
      before do
        allow(user).to receive(:email_address_count).and_return(2)
        allow(IdentityConfig.store).to receive(:max_emails_per_account).and_return(2)
      end

      it 'can add email variable set to false' do
        response
        expect(assigns(:can_add_email)).to eq(false)
      end
    end
  end

  describe '#create' do
    let(:selected_email_id) { user.confirmed_email_addresses.sample.id }
    let(:params) { { select_email_form: { selected_email_id: selected_email_id } } }

    subject(:response) { post :create, params: params }

    it 'updates selected email address' do
      response

      expect(
        controller.user_session[:selected_email_id_for_linked_identity],
      ).to eq(selected_email_id.to_s)
    end

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        :sp_select_email_submitted,
        success: true,
        needs_completion_screen_reason: :new_attributes,
        selected_email_id: selected_email_id,
      )
    end

    context ' with all_email and emails requested' do
      let(:service_provider_attribute_bundle) { %w[email all_emails] }
      let(:last_sign_in_email_id) { user.last_sign_in_email_address.id }
      let(:available_email_ids) { user.confirmed_email_addresses.map(&:id) }
      let(:selected_email_id) do
        (available_email_ids - [last_sign_in_email_id]).sample
      end

      it 'returns last sign in email' do
        response

        expect(
          controller.user_session[:selected_email_id_for_linked_identity],
        ).to eq(last_sign_in_email_id)
      end
    end

    context 'with a corrupted email selected_email_id form' do
      let(:other_user) { create(:user) }
      let(:selected_email_id) { other_user.confirmed_email_addresses.sample.id }

      it 'rejects email not belonging to the user' do
        expect(response).to redirect_to(sign_up_select_email_path)
        expect(
          controller.user_session[:selected_email_id_for_linked_identity],
        ).to eq(nil)
      end

      it 'logs analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :sp_select_email_submitted,
          success: false,
          error_details: { selected_email_id: { not_found: true } },
          needs_completion_screen_reason: :new_attributes,
          selected_email_id: selected_email_id,
        )
      end
    end

    context 'with selected email to share feature disabled' do
      before do
        allow(IdentityConfig.store).to receive(:feature_select_email_to_share_enabled)
          .and_return(false)
      end

      it 'renders 404' do
        expect(response).to be_not_found
      end
    end
  end
end
