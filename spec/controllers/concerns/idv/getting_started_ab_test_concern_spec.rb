require 'rails_helper'

RSpec.describe 'GettingStartedAbTestConcern' do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, service_provider: nil)
  end

  module Idv
    class StepController < ApplicationController
      include GettingStartedAbTestConcern

      def show
        render plain: 'Hello'
      end
    end
  end

  describe '#getting_started_a_b_test_bucket' do
    let(:sp_session) { {} }

    controller Idv::StepController do
    end

    before do
      allow(session).to receive(:id).and_return('session-id')
      allow(controller).to receive(:sp_session).and_return(sp_session)
      allow(AbTests::IDV_GETTING_STARTED).to receive(:bucket) do |discriminator|
        case discriminator
        when 'session-id'
          :welcome
        when 'request-id'
          :getting_started
        end
      end
    end

    it 'returns the bucket based on session id' do
      expect(controller.getting_started_a_b_test_bucket).to eq(:welcome)
    end

    context 'with associated sp session request id' do
      let(:sp_session) { { request_id: 'request-id' } }

      it 'returns the bucket based on request id' do
        expect(controller.getting_started_a_b_test_bucket).to eq(:getting_started)
      end
    end
  end

  context '#maybe_redirect_for_getting_started_ab_test' do
    controller Idv::StepController do
      before_action :maybe_redirect_for_getting_started_ab_test
    end

    before do
      sign_in(user)
      routes.draw do
        get 'show' => 'idv/step#show'
      end
    end

    let(:session_uuid) { SecureRandom.uuid }

    context 'A/B test specifies getting started page' do
      before do
        allow(controller).to receive(:getting_started_a_b_test_bucket).
          and_return(:getting_started)
      end

      it 'redirects to idv_getting_started_url' do
        get :show

        expect(response).to redirect_to(idv_getting_started_url)
      end
    end

    context 'A/B test specifies welcome page' do
      before do
        allow(controller).to receive(:getting_started_a_b_test_bucket).
          and_return(:welcome)
      end

      it 'does not redirect users away from welcome page' do
        get :show

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end

    context 'A/B test specifies some other value' do
      before do
        allow(controller).to receive(:getting_started_a_b_test_bucket).
          and_return(:something_else)
      end

      it 'does not redirect users away from welcome page' do
        get :show

        expect(response.body).to eq('Hello')
        expect(response.status).to eq(200)
      end
    end
  end
end
