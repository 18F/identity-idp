require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SmsOptInController do
  describe '#new' do
    subject(:action) { get :new }

    context 'when loaded while using an existing phone' do
      let(:user) { create(:user, :with_phone) }
      before do
        stub_sign_in(user)
        stub_analytics
        allow(controller).to receive(:user_session).
          and_return(phone_id: user.phone_configurations.first.id)
      end

      it 'tracks a visit event' do
        action

        expect(assigns[:has_other_auth_methods]).to eq(false)
        expect(assigns[:phone_configuration]).to eq(user.phone_configurations.first)

        expect(@analytics).to have_logged_event(
          Analytics::SMS_OPT_IN_VISIT,
          has_other_auth_methods: false,
          phone_configuration_id: user.phone_configurations.first.id,
        )
      end

      context 'when the user has other auth methods' do
        let(:user) { create(:user, :with_phone, :with_authentication_app) }

        it 'has other auth methods' do
          action

          expect(assigns[:has_other_auth_methods]).to eq(true)
        end
      end
    end

    context 'when loaded while adding a new phone' do
      let(:user) { create(:user) }
      let(:phone) { Faker::PhoneNumber.cell_phone }
      before do
        stub_sign_in_before_2fa(user)
        allow(controller).to receive(:user_session).
          and_return(unconfirmed_phone: phone)
      end

      it 'assigns an in-memory phone configuration' do
        expect { action }.to_not change { user.reload.phone_configurations.count }

        expect(assigns[:has_other_auth_methods]).to eq(false)
        expect(assigns[:phone_configuration].phone).to eq(phone)
      end
    end

    context 'when loaded without any phone context' do
      it 'renders a 404' do
        expect(action).to be_not_found
        expect(response).to render_template('pages/page_not_found')
      end
    end
  end

  describe '#create' do
    subject(:action) { post :create }

    context 'when loaded while using an existing phone' do
      let(:user) { create(:user, :with_phone) }
      before do
        stub_sign_in(user)
        stub_analytics
        allow(controller).to receive(:user_session).
          and_return(phone_id: user.phone_configurations.first.id)

        Telephony.config.pinpoint.add_sms_config do |sms|
          sms.region = 'sms-region'
          sms.access_key_id = 'fake-pnpoint-access-key-id-sms'
          sms.secret_access_key = 'fake-pinpoint-secret-access-key-sms'
          sms.application_id = 'backup-sms-application-id'
        end
      end

      context 'when resubscribing is successful' do
        before do
          Aws.config[:sns] = {
            stub_responses: {
              opt_in_phone_number: {},
              check_if_phone_number_is_opted_out: { is_opted_out: false },
            },
          }
        end

        it 'redirects to the otp send controller' do
          expect(action).to redirect_to(
            otp_send_url(otp_delivery_selection_form: { otp_delivery_preference: :sms }),
          )

          expect(@analytics).to have_logged_event(
            Analytics::SMS_OPT_IN_SUBMITTED,
            success: true,
          )
        end
      end

      context 'when resubscribing is not successful' do
        before do
          Aws.config[:sns] = {
            stub_responses: {
              opt_in_phone_number: {},
              check_if_phone_number_is_opted_out: { is_opted_out: true },
            },
          }
        end

        it 'renders an error' do
          action

          expect(response).to render_template(:error)

          expect(@analytics).to have_logged_event(
            Analytics::SMS_OPT_IN_SUBMITTED,
            success: false,
          )
        end
      end

      context 'when resubscribing throws an error' do
        before do
          Aws.config[:sns] = {
            stub_responses: {
              opt_in_phone_number: 'InternalServerErrorException',
            },
          }
        end

        it 'renders the form with a flash error' do
          action

          expect(response).to render_template(:new)
          expect(flash[:error]).to be_present

          expect(@analytics).to have_logged_event(
            Analytics::SMS_OPT_IN_SUBMITTED,
            success: false,
          )
        end
      end
    end

    context 'when loaded without any phone context' do
      it 'renders a 404' do
        expect(action).to be_not_found
        expect(response).to render_template('pages/page_not_found')
      end
    end
  end
end
