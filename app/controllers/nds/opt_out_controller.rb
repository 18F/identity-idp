# frozen_string_literal: true

module NDS
  class OptOutController < ApplicationController
    def create
      opted_out = AbTestAssignment.opt_out!(
        experiment: AbTests::NDS_LOOK_AND_FEEL.experiment,
        discriminator: nds_experiment_uuid,
      )
      return redirect_back(fallback_location: root_url, allow_other_host: false) unless opted_out

      session[:nds_ab_test_bucket] = AbTestAssignment::OPT_OUT_BUCKET
      analytics.nds_look_and_feel_opted_out

      redirect_back(fallback_location: root_url, allow_other_host: false)
    end
  end
end
