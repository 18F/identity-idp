require 'rails_helper'

RSpec.describe 'AbTestAnalyticsConcern' do
  module Idv
    class StepController < ApplicationController
      include AbTestAnalyticsConcern
    end
  end

  describe '#ab_test_analytics_args' do
    controller Idv::StepController do
    end

    it 'includes acuant_sdk_ab_test_analytics_args' do
      acuant_sdk_args = { as_bucket: :as_value }
      expect(subject).to receive(:acuant_sdk_ab_test_analytics_args).
        and_return(acuant_sdk_args)
      expect(controller.ab_test_analytics_args).to include(acuant_sdk_args)
    end

    it 'includes getting_started_ab_test_analytics_args' do
      getting_started_args = { gs_bucket: :gs_value }
      expect(subject).to receive(:acuant_sdk_ab_test_analytics_args).
        and_return(getting_started_args)
      expect(controller.ab_test_analytics_args).to include(getting_started_args)
    end
  end
end
