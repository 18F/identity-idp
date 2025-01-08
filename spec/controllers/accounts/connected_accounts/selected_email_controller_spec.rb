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
      expect(assigns(:email_id)).to eq(user.email_addresses.first.id)
    end

    context 'user has signed in with a different email address than has been assigned' do
      it 'assigns the user identity email id' do
        identity_email = user.email_addresses.last.id
        identity.email_address_id = identity_email
        identity.save

        response

        expect(assigns(:email_id)).to eq(identity_email)
      end
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

    context 'when the user already has max number of emails' do
      before do
        allow(IdentityConfig.store).to receive(:max_emails_per_account)
          .and_return(user.email_addresses.count)
      end

      it 'can add email variable set to false' do
        response
        expect(assigns(:can_add_email)).to eq(false)
      end
    end
  end

  describe '#update' do
    let(:identity_id) { user.identities.take.id }
    let(:selected_email_id) { user.confirmed_email_addresses.sample }
    let(:params) { { identity_id:, select_email_form: { selected_email_id: selected_email_id } } }
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
        selected_email_id: selected_email_id,
      )
    end

    context ' with all_email and emails requested' do
      let(:service_provider_attribute_bundle) { %w[email all_email] }

      let(:sp) do
        create(
          :service_provider,
          attribute_bundle: service_provider_attribute_bundle,
        )
      end
      let(:identity) do
        create(:service_provider_identity, :active, service_provider: sp.issuer, user: user)
      end

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
        identity.reload
        expect(identity.email_address_id).to eq(last_sign_in_email_id)
      end
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
