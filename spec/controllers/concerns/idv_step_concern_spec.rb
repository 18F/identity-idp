require 'rails_helper'

describe 'IdvStepConcern' do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, service_provider: nil)
  end

  module Idv
    class StepController < ApplicationController
      include IdvStepConcern

      def show
        render plain: 'Hello'
      end
    end
  end

  describe '#confirm_idv_needed' do
    controller Idv::StepController do
      before_action :confirm_idv_needed
    end

    before(:each) do
      sign_in(user)
      routes.draw do
        get 'show' => 'idv/step#show'
      end
    end

    context 'user has active profile' do
      before do
        allow(user).to receive(:active_profile).and_return(Profile.new)
        allow(subject).to receive(:current_user).and_return(user)
      end

      it 'redirects to activated page' do
        get :show

        expect(response).to redirect_to idv_activated_url
      end
    end

    context 'user does not have active profile' do
      before do
        allow(subject).to receive(:current_user).and_return(user)
      end

      it 'does not redirect to activated page' do
        get :show

        expect(response.body).to eq 'Hello'
        expect(response).to_not redirect_to idv_activated_url
        expect(response.status).to eq 200
      end
    end
  end

  describe '#confirm_address_step_complete' do
    controller Idv::StepController do
      before_action :confirm_address_step_complete
    end

    before(:each) do
      sign_in(user)
      routes.draw do
        get 'show' => 'idv/step#show'
      end
    end

    context 'the user has completed phone confirmation' do
      it 'does not redirect' do
        idv_session.vendor_phone_confirmation = true
        idv_session.user_phone_confirmation = true

        get :show

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end

    context 'the user has not confirmed their phone OTP' do
      it 'redirects to OTP confirmation' do
        idv_session.vendor_phone_confirmation = true
        idv_session.user_phone_confirmation = false

        get :show

        expect(response).to redirect_to(idv_otp_verification_url)
      end
    end

    context 'the user has not confirmed their phone with the vendor' do
      it 'redirects to phone confirmation' do
        idv_session.vendor_phone_confirmation = false
        idv_session.user_phone_confirmation = false

        get :show

        expect(response).to redirect_to(idv_otp_verification_url)
      end
    end

    context 'the user has selected GPO for address confirmation' do
      it 'does not redirect' do
        idv_session.address_verification_mechanism = 'gpo'

        get :show

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end
  end
end
