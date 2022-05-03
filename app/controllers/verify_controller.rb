class VerifyController < ApplicationController
  include RenderConditionConcern

  check_or_render_not_found -> { IdentityConfig.store.idv_api_enabled }, only: [:show]

  def show
    @app_data = app_data
  end

  private

  def app_data
    {
      base_path: idv_app_root_path,
      app_name: APP_NAME,
      initial_values: {
        'personalKey' => '0000-0000-0000-0000',
        'firstName' => 'Bruce',
        'lastName' => 'Wayne',
        'address1' => '1234 Batcave',
        'address2' => '',
        'city'     => 'Batcavesville',
        'state'    => 'NY',
        'zipcode'  => '12345',
        'dob' => '1988-03-30',
        'ssn' => '900-12-3456',
        'phone' => '2021234567',
      },
    }
  end
end
