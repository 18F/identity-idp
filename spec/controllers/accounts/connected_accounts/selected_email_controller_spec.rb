# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounts::ConnectedAccounts::SelectedEmailController do
  let(:identity) { create(:service_provider_identity, :active) }
  let(:user) { create(:user, :with_multiple_emails, identities: [identity]) }

  before do
    stub_sign_in(user) if user
  end

  describe '#edit' do
    let(:identity_id) { user.identities.take.id }
    let(:params) { { identity_id: } }
    subject(:response) { get :edit, params: }

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(:sp_select_email_visited)
    end

    it 'assigns view variables' do
      response

      expect(assigns(:identity)).to be_kind_of(ServiceProviderIdentity)
      expect(assigns(:select_email_form)).to be_kind_of(SelectEmailForm)
      expect(assigns(:can_add_email)).to eq(true)
    end

    context 'with an identity parameter not associated with the user' do
      let(:other_user) { create(:user, identities: [create(:service_provider_identity, :active)]) }
      let(:identity_id) { other_user.identities.take.id }

      it 'renders 404' do
        expect(response).to be_not_found
      end
    end

    context 'signed out' do
      let(:other_user) { create(:user, identities: [create(:service_provider_identity, :active)]) }
      let(:identity_id) { other_user.identities.take.id }
      let(:user) { nil }

      it 'redirects to sign in' do
        expect(response).to redirect_to new_user_session_path
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

  describe '#update' do
    let(:identity_id) { user.identities.take.id }
    let(:selected_email) { user.confirmed_email_addresses.sample }
    let(:params) { { identity_id:, select_email_form: { selected_email_id: selected_email.id } } }
    subject(:response) { patch :update, params: }

    it 'redirects to connected accounts path with the appropriate flash message' do
      expect(response).to redirect_to(account_connected_accounts_path)
      expect(flash[:email_updated_identity_id]).to eq(identity.id)
    end

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        :sp_select_email_submitted,
        success: true,
        selected_email_id: selected_email.id,
      )
    end

    context 'with invalid submission' do
      let(:params) { super().merge(select_email_form: { selected_email_id: '' }) }

      it 'redirects to form with flash' do
        expect(response).to redirect_to(edit_connected_account_selected_email_path(identity.id))
        expect(flash[:error]).to eq(t('email_address.not_found'))
      end

      it 'logs analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :sp_select_email_submitted,
          success: false,
          error_details: { selected_email_id: { blank: true, not_found: true } },
        )
      end
    end

    context 'signed out' do
      let(:other_user) { create(:user, identities: [create(:service_provider_identity, :active)]) }
      let(:selected_email) { other_user.confirmed_email_addresses.sample }
      let(:identity_id) { other_user.identities.take.id }
      let(:user) { nil }

      it 'redirects to sign in' do
        expect(response).to redirect_to new_user_session_path
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
