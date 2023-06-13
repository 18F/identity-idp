require 'rails_helper'

RSpec.describe Users::PhonesController do
  let(:user) { create(:user, :fully_registered, with: { phone: '+1 (202) 555-1234' }) }
  before do
    stub_sign_in(user)

    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  context 'user adds phone' do
    it 'gives the user a form to enter a new phone number' do
      get :add

      expect(response).to render_template(:add)
      expect(response.request.flash[:alert]).to be_nil
    end

    it 'tracks analytics' do
      expect(@analytics).to receive(:track_event).
        with('Phone Setup Visited')
      get :add
    end
  end

  context 'user exceeds phone number limit' do
    before do
      user.phone_configurations.create(encrypted_phone: '4105555551')
      user.phone_configurations.create(encrypted_phone: '4105555552')
      user.phone_configurations.create(encrypted_phone: '4105555553')
      user.phone_configurations.create(encrypted_phone: '4105555554')
    end

    it 'displays error if phone number exceeds limit' do
      controller.request.headers.merge({ HTTP_REFERER: account_url })

      get :add
      expect(response).to redirect_to(account_url(anchor: 'phones'))
      expect(response.request.flash[:phone_error]).to_not be_nil
    end

    it 'renders the #phone anchor when it exceeds limit' do
      controller.request.headers.merge({ HTTP_REFERER: account_url })

      get :add
      expect(response.location).to include('#phone')
    end

    it 'it redirects to two factor auth url if the referer was two factor auth' do
      controller.request.headers.merge({ HTTP_REFERER: account_two_factor_authentication_url })

      get :add
      expect(response).to redirect_to(account_two_factor_authentication_url(anchor: 'phones'))
    end

    it 'defaults to account url if the url is anything but two factor auth url' do
      controller.request.headers.merge({ HTTP_REFERER: add_phone_url })

      get :add
      expect(response).to redirect_to(account_url(anchor: 'phones'))
    end
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(OutageStatus).to receive(:all_phone_vendor_outage?).and_return(true)
    end

    it 'redirects to outage page' do
      get :add

      expect(response).to redirect_to vendor_outage_path(from: :users_phones)
    end
  end

  describe 'recaptcha csp' do
    before { stub_sign_in }

    it 'does not allow recaptcha in the csp' do
      expect(subject).not_to receive(:allow_csp_recaptcha_src)

      get :add
    end

    context 'recaptcha enabled' do
      before do
        allow(FeatureManagement).to receive(:phone_recaptcha_enabled?).and_return(true)
      end

      it 'allows recaptcha in the csp' do
        expect(subject).to receive(:allow_csp_recaptcha_src)

        get :add
      end
    end
  end

  describe '#create' do
    context 'with recoverable recaptcha error' do
      it 'renders spam protection template' do
        stub_sign_in

        allow(controller).to receive(:recoverable_recaptcha_error?) do |result|
          result.is_a?(FormResponse)
        end

        post :create, params: { new_phone_form: { international_code: 'CA' } }

        expect(response).to render_template('users/phone_setup/spam_protection')
      end
    end

    context 'invalid number' do
      it 'tracks an event when the number is invalid' do
        sign_in(user)

        stub_analytics
        result = {
          success: false,
          errors: {
            phone: [
              t('errors.messages.improbable_phone'),
              t(
                'two_factor_authentication.otp_delivery_preference.voice_unsupported',
                location: '',
              ),
            ],
          },
          error_details: {
            phone: [
              :improbable_phone,
              t(
                'two_factor_authentication.otp_delivery_preference.voice_unsupported',
                location: '',
              ),
            ],
          },
          otp_delivery_preference: 'sms',
          area_code: nil,
          carrier: 'Test Mobile Carrier',
          country_code: nil,
          phone_type: :mobile,
          types: [],
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
        }

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: phone setup', result)

        post :create, params: {
          new_phone_form: {
            phone: '703-555-010',
            international_code: 'US',
          },
        }

        expect(response).to render_template(:add)
      end
    end

    context 'with SMS' do
      it 'prompts to confirm the number' do
        sign_in(user)

        stub_analytics

        result = {
          success: true,
          errors: {},
          otp_delivery_preference: 'sms',
          area_code: '703',
          carrier: 'Test Mobile Carrier',
          country_code: 'US',
          phone_type: :mobile,
          types: [:fixed_or_mobile],
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
        }

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: phone setup', result)

        post(
          :create,
          params: {
            new_phone_form: { phone: '703-555-0100',
                              international_code: 'US' },
          },
        )

        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'sms',
                                           otp_make_default_number: false },
          ),
        )

        expect(subject.user_session[:context]).to eq 'confirmation'
      end
    end

    context 'without selection' do
      it 'prompts to confirm via SMS by default' do
        sign_in(user)

        stub_analytics
        result = {
          success: true,
          errors: {},
          otp_delivery_preference: 'sms',
          area_code: '703',
          carrier: 'Test Mobile Carrier',
          country_code: 'US',
          phone_type: :mobile,
          types: [:fixed_or_mobile],
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
        }

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: phone setup', result)

        patch(
          :create,
          params: {
            new_phone_form: { phone: '703-555-0100',
                              international_code: 'US' },
          },
        )

        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'sms',
                                           otp_make_default_number: false },
          ),
        )

        expect(subject.user_session[:context]).to eq 'confirmation'
      end
    end
  end
end
