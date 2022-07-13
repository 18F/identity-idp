require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SmsOptInController do
  describe '#new' do
    subject(:action) { get :new, params: { opt_out_uuid: opt_out_uuid } }

    context 'when loaded while using an existing phone' do
      let(:opt_out_uuid) do
        PhoneNumberOptOut.create_or_find_with_phone(user.phone_configurations.first.phone).uuid
      end

      let(:user) { create(:user, :with_phone) }
      let(:sp_name) { nil }
      before do
        stub_sign_in_before_2fa(user)
        stub_analytics
        allow(controller).to receive(:decorated_session).
          and_return(instance_double('SessionDecorator', sp_name: sp_name))
      end

      it 'tracks a visit event' do
        action

        expect(assigns[:phone_configuration]).to eq(user.phone_configurations.first)

        expect(@analytics).to have_logged_event(
          'SMS Opt-In: Visited',
          has_other_auth_methods: false,
          phone_configuration_id: user.phone_configurations.first.id,
        )
      end

      context 'when the user has other auth methods' do
        let(:user) { create(:user, :with_phone, :with_authentication_app) }

        it 'has an other mfa options url' do
          action

          expect(assigns[:other_mfa_options_url]).to eq(login_two_factor_options_path)
        end
      end

      context 'when the user is signing in through an SP' do
        let(:sp_name) { 'An Example SP' }

        it 'points the cancel link back to the SP' do
          action

          expect(assigns[:cancel_url]).to eq(return_to_sp_cancel_path)
        end
      end
    end

    context 'when loaded while adding a new phone' do
      let(:user) { create(:user) }
      let(:phone) { Faker::PhoneNumber.cell_phone_in_e164 }
      let(:opt_out_uuid) { PhoneNumberOptOut.create_or_find_with_phone(phone).uuid }

      before do
        stub_sign_in_before_2fa(user)
      end

      it 'assigns an in-memory phone configuration' do
        expect { action }.to_not change { user.reload.phone_configurations.count }

        expect(PhoneFormatter.format(assigns[:phone_configuration].phone)).
          to eq(PhoneFormatter.format(phone))
      end
    end

    context 'when loaded without any phone context' do
      let(:opt_out_uuid) { '-111111' }

      it 'renders a 404' do
        expect(action).to be_not_found
        expect(response).to render_template('pages/page_not_found')
      end
    end
  end

  describe '#create' do
    subject(:action) { post :create, params: { opt_out_uuid: opt_out_uuid } }

    context 'when loaded while using an existing phone' do
      let(:opt_out_uuid) do
        PhoneNumberOptOut.create_or_find_with_phone(user.phone_configurations.first.phone).uuid
      end

      let(:user) { create(:user, :with_phone) }
      before do
        stub_sign_in(user)
        stub_analytics

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
            },
          }
        end

        it 'redirects to the otp send controller' do
          expect(action).to redirect_to(
            otp_send_url(otp_delivery_selection_form: { otp_delivery_preference: :sms }),
          )

          expect(@analytics).to have_logged_event(
            'SMS Opt-In: Submitted',
            success: true,
          )
        end

        it 'deletes the opt out row' do
          action

          expect(PhoneNumberOptOut.find_by(uuid: opt_out_uuid)).to be_nil
        end
      end

      context 'when resubscribing is not successful' do
        before do
          Aws.config[:sns] = {
            stub_responses: {
              opt_in_phone_number: [
                'InvalidParameter',
                'Invalid parameter: Cannot opt in right now, latest opt in is too recent',
              ],
            },
          }
        end

        it 'renders an error' do
          action

          expect(response).to render_template(:error)

          expect(@analytics).to have_logged_event(
            'SMS Opt-In: Submitted',
            success: false,
          )
        end

        it 'does not delete the opt out row' do
          action

          expect(PhoneNumberOptOut.from_param(opt_out_uuid)).to be
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
            'SMS Opt-In: Submitted',
            success: false,
          )
        end

        it 'does not delete the opt out row' do
          action

          expect(PhoneNumberOptOut.from_param(opt_out_uuid)).to be
        end
      end
    end

    context 'when loaded without any phone context' do
      let(:opt_out_uuid) { '-111111' }

      it 'renders a 404' do
        expect(action).to be_not_found
        expect(response).to render_template('pages/page_not_found')
      end
    end
  end
end
