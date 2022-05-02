class VerifyController < ApplicationController
  include RenderConditionConcern

  # check_or_render_not_found -> { IdentityConfig.store.idv_api_enabled }, only: [:show]

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
        'pii' => { 'firstName'  => 'Bruce',
                   'lastName'   => 'Wayne',
                   'address'    => { 'address1' => '1234 Batcave',
                                     'address2' => '',
                                     'city'     => 'batcavesville',
                                     'state'    => 'NY',
                                     'zipcode'  => '12345'},
                   'dob'       => '1988-03-30',
                   'ssn'       => '900-12-3456',
                   'phone'     => '2021234567'

        },

      }
    }
  end
end
# --- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
# first_name: FAKEY
# middle_name:
#   last_name: MCFAKERSON
# address1: 1 FAKE RD
# address2:
#   city: GREAT FALLS
# state: MT
# zipcode: '59010'
# dob: '1938-10-06'
# state_id_number: '1111111111111'
# state_id_jurisdiction: ND
# state_id_type: drivers_license
# state_id_expiration: '2099-12-31'
# phone: '2015550123'
# uuid: adc7d623-a274-404a-ac0b-e2428975fae4
# uuid_prefix:
#   ssn: 900-45-6789