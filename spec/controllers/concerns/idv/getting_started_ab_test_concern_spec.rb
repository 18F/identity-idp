require 'rails_helper'

RSpec.describe 'GettingStartedAbTestConcern' do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }
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

  context "#maybe_redirect_for_getting_started_ab_test"
end
