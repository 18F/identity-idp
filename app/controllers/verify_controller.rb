class VerifyController < ApplicationController
  include RenderConditionConcern

  check_or_render_not_found -> { IdentityConfig.store.idv_api_enabled }, only: [:show]

  def show
    @app_data = app_data
  end

  private

  def app_data
    {
      initial_values: { 'personalKey' => '0000-0000-0000-0000' },
    }
  end
end
