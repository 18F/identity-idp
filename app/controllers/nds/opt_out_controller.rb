# frozen_string_literal: true

module NDS
  class OptOutController < ApplicationController
    def create
      previous_bucket = session[:nds_ab_test_bucket]

      AbTestAssignment.opt_out!(
        experiment: AbTests::NDS_LOOK_AND_FEEL.experiment,
        discriminator: nds_experiment_uuid,
      )
      session[:nds_ab_test_bucket] = AbTestAssignment::OPT_OUT_BUCKET
      cookies.delete(:ui_test_bucket)

      analytics.nds_look_and_feel_opted_out(previous_bucket: previous_bucket&.to_s)

      redirect_back(fallback_location: root_url, allow_other_host: false)
    end
  end
end
