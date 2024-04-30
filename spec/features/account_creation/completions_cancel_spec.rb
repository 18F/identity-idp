require 'rails_helper'

RSpec.feature 'asks users if they want to exit to partner agency', allowed_extra_analytics: [:*] do
  include SamlAuthHelper

  it 'redirects accordingly' do
    visit_idp_from_sp_with_ial1(:oidc)
    sign_up_and_set_password
    select_2fa_option('backup_code')
    click_continue

    expect(current_path).to eq('/sign_up/completed')

    click_cancel
  end
end
