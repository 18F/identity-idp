require 'rails_helper'

describe TwoFactorAuthentication::OtpVerificationController, devise: true do
  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      before do
        sign_in_before_2fa
      end

      context 'when FeatureManagement.prefill_otp_codes? is true' do
        it 'sets @code_value to correct OTP value' do
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
          get :show, delivery_method: 'sms'

          expect(assigns(:code_value)).to eq(subject.current_user.direct_otp)
        end
      end

      context 'when FeatureManagement.prefill_otp_codes? is false' do
        it 'does not set @code_value' do
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(false)
          get :show, delivery_method: 'sms'

          expect(assigns(:code_value)).to be_nil
        end
      end
    end
  end

  describe '#create' do
    context 'when the user enters an invalid OTP' do
      before do
        sign_in_before_2fa

        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('OTP', context: 'authentication', success?: false)

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        expect(subject.current_user).to receive(:authenticate_direct_otp).and_return(false)
        post :create, code: '12345', delivery_method: 'sms'
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the OTP entry screen' do
        expect(response).to render_template(:show)
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_otp')
      end
    end

    context 'when the user has reached the max number of OTP attempts' do
      it 'tracks the event' do
        sign_in_before_2fa

        stub_analytics

        expect(@analytics).to receive(:track_event).exactly(3).times.
          with('OTP', context: 'authentication', success?: false)
        expect(@analytics).to receive(:track_event).with('User reached max 2FA attempts')

        3.times { post :create, code: '12345', delivery_method: 'sms' }
      end
    end

    context 'when the user enters a valid OTP' do
      before do
        sign_in_before_2fa
        expect(subject.current_user).to receive(:authenticate_direct_otp).and_return(true)
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'redirects to the profile' do
        post :create, code: subject.current_user.reload.direct_otp, delivery_method: 'sms'

        expect(response).to redirect_to profile_path
      end

      it 'resets the second_factor_attempts_count' do
        subject.current_user.update(second_factor_attempts_count: 1)
        post :create, code: subject.current_user.reload.direct_otp, delivery_method: 'sms'

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('OTP', context: 'authentication', success?: true)
        expect(@analytics).to receive(:track_event).with('Authentication Successful')

        post :create, code: subject.current_user.reload.direct_otp, delivery_method: 'sms'
      end
    end

    context 'when the user lockout period expires' do
      before do
        sign_in_before_2fa
        subject.current_user.update(
          second_factor_locked_at: Time.zone.now - Devise.direct_otp_valid_for - 1.second,
          second_factor_attempts_count: 3
        )
      end

      describe 'when user submits an invalid OTP' do
        before do
          post :create, code: '12345', delivery_method: 'sms'
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end

      describe 'when user submits a valid OTP' do
        before do
          post :create, code: subject.current_user.direct_otp, delivery_method: 'sms'
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end
    end

    context 'phone confirmation' do
      before do
        sign_in_as_user
        subject.user_session[:unconfirmed_phone] = '+1 (555) 555-5555'
        @previous_phone_confirmed_at = subject.current_user.phone_confirmed_at
        subject.current_user.create_direct_otp
        stub_analytics
        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)
      end

      context 'user has an existing phone number' do
        context 'user enters a valid code' do
          before do
            post(
              :create,
              code: subject.current_user.direct_otp,
              delivery_method: 'sms',
              context: 'confirmation'
            )
          end

          it 'clears session data' do
            expect(subject.user_session[:unconfirmed_phone]).to be_nil
          end

          it 'tracks the update event' do
            expect(@analytics).to have_received(:track_event).
              with('OTP', context: 'confirmation', success?: true)

            expect(subject).to have_received(:create_user_event).with(:phone_changed)
            expect(subject).to have_received(:create_user_event).exactly(:once)
          end
        end

        context 'user enters an invalid code' do
          before { post :create, code: '999', delivery_method: 'sms', context: 'confirmation' }

          it 'does not increment second_factor_attempts_count' do
            expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
          end

          it 'does not clear session data' do
            expect(subject.user_session[:unconfirmed_phone]).to eq('+1 (555) 555-5555')
          end

          it 'does not update user phone or phone_confirmed_at attributes' do
            expect(subject.current_user.phone).to eq('+1 (202) 555-1212')
            expect(subject.current_user.phone_confirmed_at).to eq(@previous_phone_confirmed_at)
          end

          it 'renders :show' do
            expect(response).to render_template(:show)
          end

          it 'displays error flash notice' do
            expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_otp')
          end

          it 'tracks an event' do
            expect(@analytics).to have_received(:track_event).
              with('OTP', context: 'confirmation', success?: false)
          end
        end
      end

      context 'when user does not have an existing phone number' do
        before do
          subject.current_user.phone = nil
          subject.current_user.phone_confirmed_at = nil
          subject.current_user.create_direct_otp
        end

        context 'when given valid code' do
          before do
            post(
              :create,
              code: subject.current_user.direct_otp,
              delivery_method: 'sms',
              context: 'confirmation'
            )
          end

          it 'redirects to profile page' do
            expect(response).to redirect_to(profile_path)
          end

          it 'tracks the confirmation event' do
            expect(@analytics).to have_received(:track_event).
              with('OTP', context: 'confirmation', success?: true)
            expect(@analytics).to have_received(:track_event).with('Authentication Successful')

            expect(subject).to have_received(:create_user_event).with(:phone_confirmed)
            expect(subject).to have_received(:create_user_event).exactly(:once)
          end
        end
      end
    end

    context 'idv phone confirmation' do
      before do
        sign_in_as_user
        idv_session = Idv::Session.new(subject.user_session, subject.current_user)
        idv_session.params = { 'phone' => '+1 (555) 555-5555' }
        subject.user_session[:unconfirmed_phone] = '+1 (555) 555-5555'
        @previous_phone_confirmed_at = subject.current_user.phone_confirmed_at
        allow(subject).to receive(:idv_session).and_return(idv_session)
        stub_analytics
        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)
        create(
          :profile,
          :active,
          :verified,
          user: subject.current_user,
          pii: { phone: '+1 (202) 555-1212' }
        )
        subject.current_user.create_direct_otp
      end

      context 'user enters a valid code' do
        before do
          post(
            :create,
            code: subject.current_user.direct_otp,
            delivery_method: 'sms',
            context: 'idv'
          )
        end

        it 'clears session data' do
          expect(subject.user_session[:unconfirmed_phone]).to be_nil
        end

        it 'tracks the update event' do
          expect(@analytics).to have_received(:track_event).
            with('OTP', context: 'idv', success?: true)
        end

        it 'updates idv session phone_confirmed_at attribute' do
          expect(subject.user_session[:idv][:params]['phone_confirmed_at']).to_not be_nil
        end

        it 'does not update user phone attributes' do
          expect(subject.current_user.reload.phone).to eq '+1 (202) 555-1212'
          expect(subject.current_user.reload.phone_confirmed_at).to eq @previous_phone_confirmed_at
        end

        it 'redirects to idv_questions_path' do
          expect(response).to redirect_to(idv_questions_path)
        end

        it 'displays success flash notice' do
          expect(flash[:success]).to eq t('notices.phone_confirmation_successful')
        end
      end

      context 'user enters an invalid code' do
        before { post :create, code: '999', delivery_method: 'sms', context: 'idv' }

        it 'does not increment second_factor_attempts_count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'does not clear session data' do
          expect(subject.user_session[:unconfirmed_phone]).to eq('+1 (555) 555-5555')
        end

        it 'does not update user phone or phone_confirmed_at attributes' do
          expect(subject.current_user.phone).to eq('+1 (202) 555-1212')
          expect(subject.current_user.phone_confirmed_at).to eq(@previous_phone_confirmed_at)
          expect(subject.idv_session.params['phone_confirmed_at']).to be_nil
        end

        it 'renders :show' do
          expect(response).to render_template(:show)
        end

        it 'displays error flash notice' do
          expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_otp')
        end

        it 'tracks an event' do
          expect(@analytics).to have_received(:track_event).
            with('OTP', context: 'idv', success?: false)
        end
      end
    end
  end
end
