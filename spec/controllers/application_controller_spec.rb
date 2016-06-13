require 'rails_helper'

describe ApplicationController do
  describe 'handling InvalidAuthenticityToken exceptions' do
    controller do
      def index
        fail ActionController::InvalidAuthenticityToken
      end
    end

    it 'redirects to the sign in page' do
      get :index

      expect(response).to redirect_to(root_url)
    end

    it 'write to Rails log' do
      expect(Rails.logger).
        to receive(:info).with('Rescuing InvalidAuthenticityToken')

      get :index
    end

    it 'signs user out' do
      sign_in_as_user
      expect(subject.current_user).to be_present

      get :index

      expect(response).to redirect_to(root_url)
      expect(subject.current_user).to be_nil
    end
  end

  describe '#append_info_to_payload' do
    let(:payload) { {} }

    it 'adds time, user_agent and ip to the lograge output' do
      Timecop.freeze(Time.current) do
        subject.append_info_to_payload(payload)

        expect(payload.keys).to eq [:time, :user_agent, :ip]
        expect(payload.values).to eq [Time.current, request.user_agent, request.remote_ip]
      end
    end
  end

  describe '#confirm_two_factor_authenticated' do
    controller do
      before_filter :confirm_two_factor_authenticated

      def index
        render text: 'Hello'
      end
    end

    context 'when the user is not signed in' do
      it 'redirects to sign in page' do
        get :index

        expect(response).to redirect_to root_url
      end
    end

    context 'when the user may bypass 2FA' do
      it 'returns nil' do
        sign_in_as_user

        user_decorator = instance_double(UserDecorator)

        allow(UserDecorator).to receive(:new).with(subject.current_user).
          and_return(user_decorator)
        allow(user_decorator).to receive(:may_bypass_2fa?).
          and_return(true)

        get :index

        expect(response.body).to eq 'Hello'
      end
    end

    context 'when the user may not bypass 2FA and is already two-factor authenticated' do
      it 'returns nil' do
        sign_in_as_user

        user_decorator = instance_double(UserDecorator)

        allow(UserDecorator).to receive(:new).with(subject.current_user).
          and_return(user_decorator)
        allow(user_decorator).to receive(:may_bypass_2fa?).
          and_return(false)

        get :index

        expect(response.body).to eq 'Hello'
      end
    end

    context 'when the user may not bypass 2FA and is not 2FA-enabled' do
      it 'redirects to users_otp_url with a flash message' do
        user = create(:user)
        sign_in user

        user_decorator = instance_double(UserDecorator)

        allow(UserDecorator).to receive(:new).with(subject.current_user).
          and_return(user_decorator)
        allow(user_decorator).to receive(:may_bypass_2fa?).
          and_return(false)

        get :index

        expect(response).to redirect_to users_otp_url
      end
    end

    context 'when the user may not bypass 2FA and is 2FA-enabled' do
      it 'prompts user to enter their OTP' do
        sign_in_before_2fa

        user_decorator = instance_double(UserDecorator)

        allow(UserDecorator).to receive(:new).with(subject.current_user).
          and_return(user_decorator)
        allow(user_decorator).to receive(:may_bypass_2fa?).
          and_return(false)

        get :index

        expect(response).to redirect_to user_two_factor_authentication_url
      end
    end
  end
end
