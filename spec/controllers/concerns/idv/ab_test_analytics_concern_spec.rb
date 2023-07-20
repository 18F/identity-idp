require 'rails_helper'

RSpec.describe 'AbTestAnalyticsConcern' do
  module Idv
    class StepController < ApplicationController
      include AbTestAnalyticsConcern
    end
  end

  let(:user) { create(:user) }

  describe '#ab_test_analytics_buckets' do
    controller Idv::StepController do
    end

    let(:acuant_sdk_args) { { as_bucket: :as_value } }
    let(:getting_started_args) { { gs_bucket: :gs_value } }

    before do
      allow(subject).to receive(:current_user).and_return(user)
      expect(subject).to receive(:acuant_sdk_ab_test_analytics_args).
        and_return(acuant_sdk_args)
      expect(subject).to receive(:getting_started_ab_test_analytics_bucket).
        and_return(getting_started_args)
    end

    it 'includes acuant_sdk_ab_test_analytics_args' do
      expect(controller.ab_test_analytics_buckets).to include(acuant_sdk_args)
    end

    it 'includes getting_started_ab_test_analytics_bucket' do
      expect(controller.ab_test_analytics_buckets).to include(getting_started_args)
    end
  end
end
