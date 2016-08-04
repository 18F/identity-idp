require 'rails_helper'

describe Users::PhoneConfirmationController, devise: true do
  describe 'before_actions' do
    it 'includes authentication checks' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :check_for_unconfirmed_phone
      )
    end
  end

  describe '#send_code' do
    before { sign_in_as_user }

    context 'when :unconfirmed_phone is not set in session' do
      it 'redirects to rool_url' do
        get :send_code

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when :unconfirmed_phone is set in session' do
      before { subject.user_session[:unconfirmed_phone] = '+1 (555) 555-5555' }

      it 'generates a confirmation code in the session' do
        expect(subject.user_session[:phone_confirmation_code]).to be_nil
        # We're testing an implementation detail here, but it's an important one.
        expect(SecureRandom).to receive(:random_number).with(10**Devise.direct_otp_length)

        get :send_code

        expect(subject.user_session[:phone_confirmation_code].length).
          to eq(Devise.direct_otp_length)
      end

      context 'confirmation code already exists in the session' do
        before do
          subject.user_session[:unconfirmed_phone_sms_enabled] = true
          subject.user_session[:phone_confirmation_code] = '1234'
        end

        it 're-sends existing code' do
          expect(SmsSenderConfirmationJob).to receive(:perform_later).
            with('1234', '+1 (555) 555-5555')

          get :send_code
        end
      end

      context 'when phone is SMS enabled' do
        before { subject.user_session[:unconfirmed_phone_sms_enabled] = true }

        it 'sends confirmation code via SMS', twilio: true do
          expect(subject).to receive(:confirmation_code).twice.and_return('123456')

          expect(SmsSenderConfirmationJob).to receive(:perform_later).
            with('123456', '+1 (555) 555-5555')

          get :send_code
        end

        it 'does not send OTP via Voice', twilio: true do
          expect(subject).to receive(:confirmation_code).twice.and_return('123456')

          expect(VoiceSenderConfirmationJob).to_not receive(:perform_later).
            with('123456', '+1 (555) 555-5555')

          get :send_code
        end
      end

      context 'when phone is not SMS enabled' do
        before { subject.user_session[:unconfirmed_phone_sms_enabled] = false }

        it 'sends confirmation code via Voice' do
          expect(subject).to receive(:confirmation_code).twice.and_return('123456')

          expect(VoiceSenderConfirmationJob).to receive(:perform_later).
            with('123456', '+1 (555) 555-5555')

          get :send_code
        end

        it 'does not send code via SMS' do
          expect(subject).to receive(:confirmation_code).twice.and_return('123456')

          expect(SmsSenderConfirmationJob).to_not receive(:perform_later).
            with('123456', '+1 (555) 555-5555')

          get :send_code
        end
      end
    end
  end

  describe '#confirm' do
    before do
      sign_in_as_user
      subject.user_session[:unconfirmed_phone] = '+1 (555) 555-5555'
      subject.user_session[:unconfirmed_phone_sms_enabled] = false
      subject.user_session[:phone_confirmation_code] = '123'
      @previous_phone_confirmed_at = subject.current_user.phone_confirmed_at
    end

    context 'user has an existing phone number' do
      context 'user enters a valid code' do
        before { post :confirm, code: '123' }

        it 'clears session data' do
          expect(subject.user_session[:unconfirmed_phone]).to be_nil
          expect(subject.user_session[:unconfirmed_phone_sms_enabled]).to be_nil
          expect(subject.user_session[:phone_confirmation_code]).to be_nil
        end

        it 'updates user phone and phone_confirmed_at attributes' do
          expect(subject.current_user.phone).to eq('+1 (555) 555-5555')
          expect(subject.current_user.phone_confirmed_at).to_not eq(@previous_phone_confirmed_at)
        end

        it 'redirects to profile_path' do
          expect(response).to redirect_to(profile_path)
        end

        it 'displays success flash notice' do
          expect(flash[:success]).to eq t('notices.phone_confirmation_successful')
        end
      end

      context 'user enters an invalid code' do
        before { post :confirm, code: '999' }

        it 'does not clear session data' do
          expect(subject.user_session[:unconfirmed_phone]).to eq('+1 (555) 555-5555')
          expect(subject.user_session[:unconfirmed_phone_sms_enabled]).to eq(false)
          expect(subject.user_session[:phone_confirmation_code]).to eq('123')
        end

        it 'does not update user phone or phone_confirmed_at attributes' do
          expect(subject.current_user.phone).to eq('+1 (202) 555-1212')
          expect(subject.current_user.phone_sms_enabled).to eq(true)
          expect(subject.current_user.phone_confirmed_at).to eq(@previous_phone_confirmed_at)
        end

        it 'redirects back phone_confirmation_path' do
          expect(response).to redirect_to(phone_confirmation_path)
        end

        it 'displays error flash notice' do
          expect(flash[:error]).to eq t('errors.invalid_confirmation_code')
        end
      end

      it 'tracks the update and confirmation event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with('User confirmed their phone number')
        expect(@analytics).to receive(:track_event).
          with('User changed and confirmed their phone number')

        post :confirm, code: '123'
      end

      it 'tracks an event when the user enters an invalid code' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('User entered invalid phone confirmation code')

        post :confirm, code: '999'
      end
    end

    context 'when user does not have an existing phone number' do
      before do
        subject.current_user.phone = nil
        subject.current_user.phone_confirmed_at = nil
      end

      context 'when given valid code' do
        before { post :confirm, code: '123' }

        it 'redirects to profile page' do
          expect(response).to redirect_to(profile_path)
        end
      end

      it 'tracks the confirmation event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with('User confirmed their phone number')
        expect(@analytics).to receive(:track_event).with('Authentication Successful')

        post :confirm, code: '123'
      end
    end
  end

  describe '#show' do
    before do
      sign_in_as_user
      subject.user_session[:unconfirmed_phone] = '+1 (555) 555-5555'
      subject.user_session[:unconfirmed_phone_sms_enabled] = true
    end

    it 'renders the :show template' do
      get :show

      expect(response).to render_template(:show)
    end

    it 'sets @fallback_confirmation_link for voice' do
      get :show

      expect(assigns(:sms_enabled)).to eq(true)
      expect(assigns(:fallback_confirmation_link)).to eq(phone_confirmation_disable_sms_path)
    end

    it 'tracks the pageview' do
      stub_analytics
      expect(@analytics).to receive(:track_pageview)

      get :show
    end

    context 'when updating an existing phone number' do
      it 'sets @reenter_phone_number_path to profile edit path' do
        get :show

        expect(assigns(:reenter_phone_number_path)).to eq(profile_path)
      end
    end

    context 'when choosing voice OTP' do
      before do
        sign_in_as_user
        subject.user_session[:unconfirmed_phone] = '+1 (555) 555-5555'
        subject.user_session[:unconfirmed_phone_sms_enabled] = false
      end

      it 'sets @fallback_confirmation_link for sms' do
        get :show

        expect(assigns(:sms_enabled)).to eq(false)
        expect(assigns(:fallback_confirmation_link)).to eq(phone_confirmation_enable_sms_path)
      end
    end

    context 'when entering phone number for the first time' do
      before { subject.current_user.phone = nil }

      it 'sets @reenter_phone_number_path to OTP setup path' do
        get :show

        expect(assigns(:reenter_phone_number_path)).to eq(phone_setup_path)
      end
    end

    context 'when FeatureManagement.prefill_otp_codes? is true' do
      it 'sets @code_value to correct OTP value' do
        allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
        get :show

        expect(assigns(:code_value)).to eq(subject.current_user.direct_otp)
      end
    end

    context 'when FeatureManagement.prefill_otp_codes? is false' do
      it 'does not set @code_value' do
        allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(false)
        get :show

        expect(assigns(:code_value)).to be_nil
      end
    end
  end

  describe '#disable_sms' do
    before do
      sign_in_as_user
      subject.user_session[:unconfirmed_phone] = '+1 (555) 555-5555'
      subject.user_session[:unconfirmed_phone_sms_enabled] = true
      subject.confirmation_code = '876543'
    end

    it 'sets session var unconfirmed_phone_sms_enabled to false' do
      get :disable_sms

      expect(subject.user_session[:unconfirmed_phone_sms_enabled]).to be(false)
    end

    it 'resends OTP and prompts for confirmation' do
      expect(VoiceSenderConfirmationJob).to receive(:perform_later).
        with('876543', '+1 (555) 555-5555')
      expect(SmsSenderConfirmationJob).to_not receive(:perform_later).
        with('876543', '+1 (555) 555-5555')

      get :disable_sms

      expect(subject).to redirect_to(phone_confirmation_path)
    end
  end

  describe '#enable_sms' do
    before do
      @user = sign_in_as_user(create(:user))
      subject.user_session[:unconfirmed_phone] = '+1 (555) 555-5555'
      subject.user_session[:unconfirmed_phone_sms_enabled] = false
      subject.confirmation_code = '987654'
    end

    it 'sets session var unconfirmed_phone_sms_enabled to false' do
      get :enable_sms

      expect(subject.user_session[:unconfirmed_phone_sms_enabled]).to be(true)
    end

    it 'resends OTP and prompts for confirmation' do
      expect(SmsSenderConfirmationJob).to receive(:perform_later).
        with('987654', '+1 (555) 555-5555')
      expect(VoiceSenderConfirmationJob).to_not receive(:perform_later).
        with('987654', '+1 (555) 555-5555')

      get :enable_sms

      expect(subject).to redirect_to(phone_confirmation_path)
    end
  end
end
