require 'rails_helper'

describe Users::PhoneConfirmationController, devise: true do
  describe 'before_actions' do
    it 'includes authentication checks' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :check_for_unconfirmed_mobile
      )
    end
  end

  describe '#send_code' do
    before { sign_in_as_user }

    context 'when :unconfirmed_mobile is not set in session' do
      it 'redirects to rool_url' do
        get :send_code

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when :unconfirmed_mobile is set in session' do
      before { subject.user_session[:unconfirmed_mobile] = '+1 (555) 555-5555' }

      it 'generates a confirmation code in the session' do
        expect(subject.user_session[:phone_confirmation_code]).to be_nil
        # We're testing an implementation detail here, but it's an important one.
        expect(SecureRandom).to receive(:random_number).with(10**Devise.direct_otp_length)

        get :send_code

        expect(subject.user_session[:phone_confirmation_code].length).
          to eq(Devise.direct_otp_length)
      end

      it 'sends confirmation code via SMS' do
        allow(SmsSenderConfirmationJob).to receive(:perform_later)

        get :send_code

        expect(SmsSenderConfirmationJob).to have_received(:perform_later).
          with(subject.user_session[:phone_confirmation_code], '+1 (555) 555-5555')
      end

      context 'confirmation code already exists in the session' do
        before { subject.user_session[:phone_confirmation_code] = '1234' }

        it 're-sends existing code' do
          allow(SmsSenderConfirmationJob).to receive(:perform_later)

          get :send_code

          expect(SmsSenderConfirmationJob).
            to have_received(:perform_later).with('1234', '+1 (555) 555-5555')
        end
      end
    end
  end

  describe '#confirm' do
    before do
      sign_in_as_user
      subject.user_session[:unconfirmed_mobile] = '+1 (555) 555-5555'
      subject.user_session[:phone_confirmation_code] = '123'
      @previous_mobile_confirmed_at = subject.current_user.mobile_confirmed_at
    end

    context 'user has an existing mobile number' do
      context 'user enters a valid code' do
        before { post :confirm, code: '123' }

        it 'clears session data' do
          expect(subject.user_session[:unconfirmed_mobile]).to be_nil
          expect(subject.user_session[:phone_confirmation_code]).to be_nil
        end

        it 'updates user mobile and mobile_confirmed_at attributes' do
          expect(subject.current_user.mobile).to eq('+1 (555) 555-5555')
          expect(subject.current_user.mobile_confirmed_at).to_not eq(@previous_mobile_confirmed_at)
        end

        it 'redirects to edit_user_registration_path' do
          expect(response).to redirect_to(edit_user_registration_path)
        end

        it 'displays success flash notice' do
          expect(flash[:success]).to eq t('notices.phone_confirmation_successful')
        end
      end

      context 'user enters an invalid code' do
        before { post :confirm, code: '999' }

        it 'does not clear session data' do
          expect(subject.user_session[:unconfirmed_mobile]).to eq('+1 (555) 555-5555')
          expect(subject.user_session[:phone_confirmation_code]).to eq('123')
        end

        it 'does not update user mobile or mobile_confirmed_at attributes' do
          expect(subject.current_user.mobile).to eq('+1 (202) 555-1212')
          expect(subject.current_user.mobile_confirmed_at).to eq(@previous_mobile_confirmed_at)
        end

        it 'redirects back phone_confirmation_path' do
          expect(response).to redirect_to(phone_confirmation_path)
        end

        it 'displays error flash notice' do
          expect(flash[:error]).to eq t('errors.invalid_confirmation_code')
        end
      end

      it 'tracks the update and confirmation event' do
        stub_analytics(subject.current_user)
        expect(@analytics).to receive(:track_event).with('User confirmed their phone number')
        expect(@analytics).to receive(:track_event).
          with('User changed and confirmed their phone number')

        post :confirm, code: '123'
      end

      it 'tracks an event when the user enters an invalid code' do
        stub_analytics(subject.current_user)
        expect(@analytics).to receive(:track_event).
          with('User entered invalid phone confirmation code')

        post :confirm, code: '999'
      end
    end

    context 'user does not have an existing mobile number' do
      before do
        subject.current_user.mobile = nil
        subject.current_user.mobile_confirmed_at = nil
      end

      context 'when given valid code' do
        before { post :confirm, code: '123' }

        it 'redirects to profile page' do
          expect(response).to redirect_to(profile_path)
        end
      end

      it 'tracks the confirmation event' do
        stub_analytics(subject.current_user)
        expect(@analytics).to receive(:track_event).with('User confirmed their phone number')
        expect(@analytics).to receive(:track_event).with('Authentication Successful')

        post :confirm, code: '123'
      end
    end
  end

  describe '#show' do
    before do
      sign_in_as_user
      subject.user_session[:unconfirmed_mobile] = '+1 (555) 555-5555'
    end

    it 'renders the :show template' do
      get :show

      expect(response).to render_template(:show)
    end

    it 'tracks the pageview' do
      stub_analytics(subject.current_user)
      expect(@analytics).to receive(:track_pageview)

      get :show
    end

    context 'when updating an existing phone number' do
      it 'sets @reenter_phone_number_path to profile edit path' do
        get :show

        expect(assigns(:reenter_phone_number_path)).to eq(edit_user_registration_path)
      end
    end

    context 'when entering phone number for the first time' do
      before { subject.current_user.mobile = nil }

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
end
