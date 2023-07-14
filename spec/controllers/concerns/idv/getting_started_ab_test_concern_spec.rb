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

    it 'does not redirect users getting existing experience' do
      # user goes in bucket A
      get :show

      expect(response.body).to eq('Hello')
      expect(response.status).to eq(200)
    end

    it 'redirects to idv_getting_started_url for users getting the new experience' do
      # user goes in bucket B
      get :show

      expect(response).to redirect_to(idv_getting_started_url)
    end
  end
end
