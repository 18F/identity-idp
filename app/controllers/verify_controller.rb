class VerifyController < ApplicationController
  include RenderConditionConcern

  check_or_render_not_found -> { IdentityConfig.store.idv_api_enabled }, only: [:show]

  def show; end
end
