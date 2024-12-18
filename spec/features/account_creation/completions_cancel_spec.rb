require 'rails_helper'

RSpec.feature 'canceling at the completions screen' do
  include SamlAuthHelper

  it 'redirects accordingly' do
    visit_idp_from_sp_with_ial1(:oidc)
    sign_up_and_set_password
    select_2fa_option('backup_code')
    click_continue

    expect(page).to have_current_path(sign_up_completed_path)

    click_on t('links.cancel')

    expect(page).to have_current_path(sign_up_completed_cancel_path)
    click_on t('login_cancel.keep_going')

    expect(page).to have_current_path(sign_up_completed_path)
    click_on t('links.cancel')

    expect(page).to have_current_path(sign_up_completed_cancel_path)
    click_on t('login_cancel.exit', app_name: APP_NAME)

    expect(current_url).to start_with('http://localhost:7654/auth/result?error=access_denied')
  end
end
