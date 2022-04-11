class VerifyController < ApplicationController
  include RenderConditionConcern

  render_if -> { IdentityConfig.store.idv_api_enabled }, only: [:show]

  def show; end
end
