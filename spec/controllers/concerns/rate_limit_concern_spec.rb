require 'rails_helper'

describe 'RateLimitConcern' do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }

  module Idv
    class StepController < ApplicationController
      include RateLimitConcern
      include IdvSession

      def show
        render plain: 'Hello'
      end

      def update
        render plain: 'Bye'
      end
    end
  end

  describe '#confirm_not_rate_limited' do
    controller Idv::StepController do
      before_action :confirm_not_rate_limited
    end

    before(:each) do
      sign_in(user)
      allow(subject).to receive(:current_user).and_return(user)
      routes.draw do
        get 'show' => 'idv/step#show'
        put 'update' => 'idv/step#update'
      end
    end

    context 'user is not throttled' do
      let(:user) { create(:user, :fully_registered) }

      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
        expect(response.status).to eq 200
      end
    end

    context 'with idv_doc_auth throttle (DocumentCapture)' do
      it 'redirects to idv_doc_auth throttled error page' do
        throttle = Throttle.new(user: user, throttle_type: :idv_doc_auth)
        throttle.increment_to_throttled!

        get :show

        expect(response).to redirect_to idv_session_errors_throttled_url
      end
    end

    context 'with idv_resolution throttle (VerifyInfo)' do
      it 'redirects to idv_resolution throttled error page' do
        throttle = Throttle.new(user: user, throttle_type: :idv_resolution)
        throttle.increment_to_throttled!

        get :show

        expect(response).to redirect_to idv_session_errors_failure_url
      end
    end

    context 'with proof_address throttle (PhoneStep)' do
      before do
        throttle = Throttle.new(user: user, throttle_type: :proof_address)
        throttle.increment_to_throttled!
      end

      it 'redirects to proof_address throttled error page' do
        get :show

        expect(response).to redirect_to idv_phone_errors_failure_url
      end

      context 'controller and throttle match' do
        before do
          allow(subject).to receive(:throttle_and_controller_match).
            and_return(true)
        end

        it 'redirects on show' do
          get :show

          expect(response).to redirect_to idv_phone_errors_failure_url
        end

        it 'does not redirect on update' do
          put :update

          expect(response.body).to eq 'Bye'
          expect(response.status).to eq 200
        end
      end
    end
  end
end
