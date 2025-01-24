require 'rails_helper'

RSpec.describe Users::EmailConfirmationsController do
  describe '#create' do
    describe 'Valid email confirmation tokens' do
      it 'tracks a valid email confirmation token event' do
        stub_analytics

        user = create(:user)
        new_email = Faker::Internet.email

        expect(PushNotification::HttpPush).to receive(:deliver).once
          .with(PushNotification::EmailChangedEvent.new(
            user: user,
            email: new_email,
          )).ordered

        expect(PushNotification::HttpPush).to receive(:deliver).once
          .with(PushNotification::RecoveryInformationChangedEvent.new(
            user: user,
          )).ordered

        add_email_form = AddUserEmailForm.new
        add_email_form.submit(user, email: new_email)
        email_record = add_email_form.email_address_record(new_email)

        get :create, params: { confirmation_token: email_record.reload.confirmation_token }

        expect(@analytics).to have_logged_event(
          'Add Email: Email Confirmation',
          success: true,
          from_select_email_flow: false,
          user_id: user.uuid,
        )
      end

      context 'when select email feature is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:feature_select_email_to_share_enabled)
            .and_return(false)
        end
        it 'should render proper flash member' do
          flash_message = t('devise.confirmations.confirmed')
          user = create(:user)
          sign_in user
          new_email = Faker::Internet.email

          add_email_form = AddUserEmailForm.new
          add_email_form.submit(user, email: new_email)
          email_record = add_email_form.email_address_record(new_email)

          get :create, params: { confirmation_token: email_record.reload.confirmation_token }
          expect(flash[:success]).to eq(flash_message)
        end
      end

      it 'rejects an otherwise valid token for unconfirmed users' do
        user = create(:user, :unconfirmed, email_addresses: [])
        new_email = Faker::Internet.email

        add_email_form = AddUserEmailForm.new
        add_email_form.submit(user, email: new_email)
        email_record = add_email_form.email_address_record(new_email)

        get :create, params: { confirmation_token: email_record.reload.confirmation_token }
        expect(user.email_addresses.confirmed.count).to eq 0
        expect(email_record.reload.confirmed_at).to eq nil
        expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      end

      it 'rejects expired tokens' do
        user = create(:user)
        new_email = Faker::Internet.email

        add_email_form = AddUserEmailForm.new
        add_email_form.submit(user, email: new_email)
        email_record = add_email_form.email_address_record(new_email)

        travel(IdentityConfig.store.add_email_link_valid_for_hours.hours + 1.minute) do
          get :create, params: { confirmation_token: email_record.reload.confirmation_token }
        end

        expect(email_record.reload.confirmed_at).to eq nil
        expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      end

      it 'rejects invalid tokens' do
        get :create, params: { confirmation_token: 'abc' }
        expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      end
    end

    describe 'Invalid email confirmation tokens' do
      it 'rejects invalid parameters' do
        get :create, params: { confirmation_token: { confirmation_token: 'abc' } }
        expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      end
    end

    describe '#process_successful_confirmation' do
      let(:user) { create(:user) }

      context 'adding an email from the account page' do
        before do
          stub_sign_in(user)
        end

        it 'redirects to the account page' do
          new_email = Faker::Internet.email

          add_email_form = AddUserEmailForm.new
          add_email_form.submit(user, email: new_email)
          email_record = add_email_form.email_address_record(new_email)

          get :create, params: { confirmation_token: email_record.reload.confirmation_token }

          expect(response).to redirect_to(account_url)
        end
      end

      context 'adding an email from the service provider consent flow' do
        let(:confirmation_token) { 'token' }
        let(:sp_request_uuid) { 'request-id' }
        let(:request_id_param) {}

        before do
          stub_sign_in(user)
          ServiceProviderRequestProxy.create(
            issuer: 'http://localhost:3000',
            url: '',
            uuid: sp_request_uuid,
            ial: '1',
            acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'adds an email from the service provider consent flow' do
          stub_analytics
          new_email = Faker::Internet.email
          add_email_form = AddUserEmailForm.new
          add_email_form.submit(user, email: new_email, request_id: sp_request_uuid)
          email_record = add_email_form.email_address_record(new_email)

          get :create, params: {
            confirmation_token: email_record.reload.confirmation_token,
            request_id: sp_request_uuid,
            from_select_email_flow: 'true',
          }

          expect(@analytics).to have_logged_event(
            'Add Email: Email Confirmation',
            success: true,
            from_select_email_flow: true,
            user_id: user.uuid,
          )
          expect(response).to redirect_to(sign_up_select_email_url)
        end
      end
    end
  end
end
