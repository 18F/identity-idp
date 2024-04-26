require 'rails_helper'

RSpec.describe Users::PhoneSetupController, allowed_extra_analytics: [:*] do
  include ActionView::Helpers::DateHelper

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
        expect(@analytics).to receive(:track_event).
          with('User Registration: phone setup visited',
               { enabled_mfa_methods_count: 0 })
        expect(NewPhoneForm).to receive(:new).with(
          user:,
          analytics: kind_of(Analytics),
          setup_voice_preference: false,
        )

        get :index

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
      result = {
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

      expect(response).to render_template(:index)
      expect(flash[:error]).to be_blank
    end

    context 'with recaptcha error' do
      before do
        allow(FeatureManagement).to receive(:phone_recaptcha_enabled?).and_return(true)
        allow(IdentityConfig.store).to receive(:phone_recaptcha_country_score_overrides).
          and_return({})
        allow(IdentityConfig.store).to receive(:phone_recaptcha_score_threshold).and_return(0.6)
      end

      it 'renders form with error message' do
        stub_sign_in

        post :create, params: { new_phone_form: { phone: '3065550100', international_code: 'CA' } }

        expect(response).to render_template(:index)
        expect(flash[:error]).to eq(t('errors.messages.invalid_recaptcha_token'))
      end
    end

    context 'with voice' do
      let(:user) { create(:user, otp_delivery_preference: 'voice') }

      it 'prompts to confirm the number' do
        sign_in(user)

        stub_analytics
        result = {
          success: true,
          errors: {},
          otp_delivery_preference: 'voice',
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
  describe 'check_phone_submission_limit' do
    before do
      @user = create(:user)
      @user2 = create(:user)
      @unconfirmed_phone = '+1 (202) 555-1213'
    end
    it 'rate limits use of phone by fingerprint' do
      sign_in_before_2fa(@user)
      allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(999)

      freeze_time do
        IdentityConfig.store.phone_submissions_per_fingerprint_limit.times do
          post(:create, params: { new_phone_form: { phone: @unconfirmed_phone } })
        end

        expect(@user.reload.second_factor_locked_at).to eq Time.zone.now

        timeout = distance_of_time_in_words(
          RateLimiter.attempt_window_in_minutes(:phone_fingerprint_confirmations).minutes,
        )

        expect(flash[:error]).to eq(
          I18n.t(
            'errors.messages.phone_confirmation_limited',
            timeout: timeout,
          ),
        )
        expect(response).to redirect_to account_path

        sign_out(@user)
        sign_in_before_2fa(@user2)
        post(:create, params: { new_phone_form: { phone: @unconfirmed_phone } })
        expect(@user2.reload.second_factor_locked_at).to eq Time.zone.now

        expect(flash[:error]).to eq(
          I18n.t(
            'errors.messages.phone_confirmation_limited',
            timeout: timeout,
          ),
        )
        expect(response).to redirect_to account_path
      end
    end
  end
end
