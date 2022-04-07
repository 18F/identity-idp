class VerifyController < ApplicationController
  include FeatureFlaggedConcern

  feature_flagged :idv_api_enabled, only: [:show]

  def show; end
end
