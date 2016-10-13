require 'rails_helper'

describe Idv::PhoneConfirmationController, devise: true do
  describe 'before_actions' do
    it 'includes authentication checks' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :check_for_unconfirmed_phone
      )
    end
  end

  describe '#send_code' do
    before { stub_sign_in }

    context 'when :idv_unconfirmed_phone is not set in session' do
      it 'redirects to rool_url' do
        get :send_code

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when :idv_unconfirmed_phone is set in session' do
      before { subject.user_session[:idv_unconfirmed_phone] = '+1 (555) 555-5555' }

      it 'generates a confirmation code in the session' do
        expect(subject.user_session[:idv_phone_confirmation_code]).to be_nil
        # We're testing an implementation detail here, but it's an important one.
        expect(SecureRandom).to receive(:random_number).with(10**Devise.direct_otp_length)

        get :send_code

        expect(subject.user_session[:idv_phone_confirmation_code].length).
          to eq(Devise.direct_otp_length)
      end

      it 'sends confirmation code via SMS' do
        allow(SmsSenderOtpJob).to receive(:perform_later)

        get :send_code

        expect(SmsSenderOtpJob).to have_received(:perform_later).
          with(
            code: subject.user_session[:idv_phone_confirmation_code],
            phone: '+1 (555) 555-5555',
            otp_created_at: subject.current_user.direct_otp_sent_at.to_s
          )
      end

      context 'confirmation code already exists in the session' do
        before { subject.user_session[:idv_phone_confirmation_code] = '1234' }

        it 're-sends existing code' do
          allow(SmsSenderOtpJob).to receive(:perform_later)

          get :send_code

          expect(SmsSenderOtpJob).to have_received(:perform_later).
            with(
              code: '1234',
              phone: '+1 (555) 555-5555',
              otp_created_at: subject.current_user.direct_otp_sent_at.to_s
            )
        end
      end
    end
  end

  describe '#confirm' do
    before do
      user = stub_sign_in
      idv_session = Idv::Session.new(subject.user_session, user)
      idv_session.params = { 'phone' => '+1 (555) 555-5555' }
      subject.user_session[:idv_unconfirmed_phone] = '+1 (555) 555-5555'
      subject.user_session[:idv_phone_confirmation_code] = '123'
      allow(subject).to receive(:idv_session).and_return(idv_session)
    end

    context 'user has an existing phone number' do
      before do
        create(:profile, :active, :verified, user: subject.current_user, phone: '123-456-7890')
      end

      context 'user enters a valid code' do
        before { post :confirm, code: '123' }

        it 'clears session data' do
          expect(subject.user_session[:idv_unconfirmed_phone]).to be_nil
          expect(subject.user_session[:idv_phone_confirmation_code]).to be_nil
        end

        it 'updates user phone and phone_confirmed_at attributes' do
          expect(subject.user_session[:idv][:params]['phone_confirmed_at']).to_not be_nil
        end

        it 'redirects to idv_questions_path' do
          expect(response).to redirect_to(idv_questions_path)
        end

        it 'displays success flash notice' do
          expect(flash[:success]).to eq t('notices.phone_confirmation_successful')
        end
      end

      context 'user enters an invalid code' do
        before { post :confirm, code: '999', otp_method: :sms }

        it 'does not clear session data' do
          expect(subject.user_session[:idv_unconfirmed_phone]).to eq('+1 (555) 555-5555')
          expect(subject.user_session[:idv_phone_confirmation_code]).to eq('123')
        end

        it 'does not update phone_confirmed_at attribute' do
          expect(subject.idv_session.params['phone_confirmed_at']).to be_nil
        end

        it 'redirects back phone_confirmation_path' do
          expect(response).to redirect_to(
            idv_phone_confirmation_path(otp_method: :sms)
          )
        end

        it 'displays error flash notice' do
          expect(flash[:error]).to eq t('errors.invalid_confirmation_code')
        end
      end

      it 'tracks the confirmation event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('User confirmed their verified phone number')

        post :confirm, code: '123'
      end

      it 'tracks an event when the user enters an invalid code' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('User entered invalid phone confirmation code')

        post :confirm, code: '999'
      end
    end
  end

  describe '#show' do
    before do
      stub_sign_in
      subject.user_session[:idv_unconfirmed_phone] = '+1 (555) 555-5555'
    end

    it 'renders the :show template' do
      get :show

      expect(response).to render_template(:show)
    end

    context 'when trying to change asserted number' do
      it 'sets @reenter_phone_number_path to idv sessions path' do
        get :show

        expect(assigns(:reenter_phone_number_path)).to eq(idv_session_path)
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
