require 'rails_helper'

RSpec.describe Users::PhoneSetupController do
  let(:mfa_selections) { ['voice'] }
  before do
    allow(IdentityConfig.store).to receive(:phone_service_check).and_return(true)
  end

  describe 'GET index' do
    context 'when signed out' do
      it 'redirects to sign in page' do
        get :index

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'when signed in' do
      let(:user) { build(:user, otp_delivery_preference: 'voice') }
      before do
        stub_analytics
        stub_sign_in_before_2fa(user)
        subject.user_session[:mfa_selections] = ['voice']
        subject.user_session[:in_account_creation_flow] = true
      end

      it 'renders the index view' do
        expect(NewPhoneForm).to receive(:new).with(
          user:,
          analytics: kind_of(Analytics),
          setup_voice_preference: false,
        )

        get :index

        expect(@analytics).to have_logged_event(
          'User Registration: phone setup visited',
          { enabled_mfa_methods_count: 0 },
        )
        expect(response).to render_template(:index)
      end
    end

    context 'when fully registered and partially signed in' do
      it 'redirects to 2FA page' do
        stub_analytics
        user = build(:user, :with_phone)
        stub_sign_in_before_2fa(user)

        get :index

        expect(response).to redirect_to(user_two_factor_authentication_path)
      end
    end
  end

  describe 'PATCH create' do
    let(:user) { create(:user) }

    it 'tracks an event when the number is invalid' do
      sign_in(user)
      stub_analytics

      post :create, params: {
        new_phone_form: {
          phone: '703-555-010',
          international_code: 'US',
        },
      }

      expect(@analytics).to have_logged_event(
        'Multi-Factor Authentication: phone setup',
        success: false,
        errors: {
          phone: [
            t('errors.messages.improbable_phone'),
            t('two_factor_authentication.otp_delivery_preference.voice_unsupported', location: ''),
          ],
        },
        error_details: {
          phone: {
            improbable_phone: true,
            voice_unsupported: true,
          },
        },
        otp_delivery_preference: 'sms',
        carrier: 'Test Mobile Carrier',
        phone_type: :mobile,
        types: [],
      )
      expect(response).to render_template(:index)
      expect(flash[:error]).to be_blank
    end

    context 'with recaptcha enabled' do
      before do
        allow(FeatureManagement).to receive(:phone_recaptcha_enabled?).and_return(true)
        allow(IdentityConfig.store).to receive(:phone_recaptcha_country_score_overrides)
          .and_return({})
        allow(IdentityConfig.store).to receive(:phone_recaptcha_score_threshold).and_return(0.6)
      end

      context 'with recaptcha success' do
        it 'assigns assessment id to user session' do
          recaptcha_token = 'token'
          stub_sign_in

          post(
            :create,
            params: {
              new_phone_form: {
                phone: '3065550100',
                international_code: 'CA',
                recaptcha_token:,
                recaptcha_mock_score: '0.7',
              },
            },
          )

          expect(controller.user_session[:phone_recaptcha_assessment_id]).to be_kind_of(String)
        end
      end

      context 'with recaptcha error' do
        it 'renders form with error message' do
          stub_sign_in

          post(
            :create,
            params: { new_phone_form: { phone: '3065550100', international_code: 'CA' } },
          )

          expect(response).to render_template(:index)
          expect(flash[:error]).to eq(t('errors.messages.invalid_recaptcha_token'))
        end
      end
    end

    context 'with voice' do
      let(:user) { create(:user, otp_delivery_preference: 'voice') }

      it 'prompts to confirm the number' do
        sign_in(user)
        stub_analytics

        post(
          :create,
          params: {
            new_phone_form: { phone: '703-555-0100',
                              international_code: 'US' },
          },
        )

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication: phone setup',
          success: true,
          otp_delivery_preference: 'voice',
          area_code: '703',
          carrier: 'Test Mobile Carrier',
          country_code: 'US',
          phone_type: :mobile,
          types: [:fixed_or_mobile],
        )
        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'voice',
                                           otp_make_default_number: false },
          ),
        )
        expect(subject.user_session[:context]).to eq 'confirmation'
      end
    end

    context 'with SMS' do
      it 'prompts to confirm the number' do
        sign_in(user)
        stub_analytics

        post(
          :create,
          params: {
            new_phone_form: { phone: '703-555-0100',
                              international_code: 'US' },
          },
        )

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication: phone setup',
          success: true,
          otp_delivery_preference: 'sms',
          area_code: '703',
          carrier: 'Test Mobile Carrier',
          country_code: 'US',
          phone_type: :mobile,
          types: [:fixed_or_mobile],
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

        patch(
          :create,
          params: {
            new_phone_form: { phone: '703-555-0100',
                              international_code: 'US' },
          },
        )

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication: phone setup',
          success: true,
          otp_delivery_preference: 'sms',
          area_code: '703',
          carrier: 'Test Mobile Carrier',
          country_code: 'US',
          phone_type: :mobile,
          types: [:fixed_or_mobile],
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

  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user,
      )
    end

    describe 'recaptcha csp' do
      before { stub_sign_in }

      it 'does not allow recaptcha in the csp' do
        expect(subject).not_to receive(:allow_csp_recaptcha_src)

        get :index
      end

      context 'recaptcha enabled' do
        before do
          allow(FeatureManagement).to receive(:phone_recaptcha_enabled?).and_return(true)
        end

        it 'allows recaptcha in the csp' do
          expect(subject).to receive(:allow_csp_recaptcha_src)

          get :index
        end
      end
    end
  end

  describe 'after actions' do
    before { stub_sign_in }

    it 'does not add recaptcha resource hints' do
      expect(subject).not_to receive(:add_recaptcha_resource_hints)

      get :index
    end

    context 'recaptcha enabled' do
      before do
        allow(FeatureManagement).to receive(:phone_recaptcha_enabled?).and_return(true)
      end

      it 'adds recaptcha resource hints' do
        expect(subject).to receive(:add_recaptcha_resource_hints)

        get :index
      end
    end
  end
end
