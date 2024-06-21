require 'rails_helper'

RSpec.describe 'bug on the GPO spec', allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include OidcAuthHelper

  scenario 'the bug', :js do
    user = user_with_2fa
    start_idv_from_sp(biometric_comparison_required: false)
    complete_idv_steps_before_gpo_step(user)
    click_on t('idv.buttons.mail.send')
    fill_in 'Password', with: user_password
    click_continue
    visit sign_out_url

    travel_to 1.week.from_now do
      start_idv_from_sp(biometric_comparison_required: true)
      sign_in_live_with_2fa(user)

      # The user should go into the proofing flow since they are upgrading
      # to a biometric profile
      #
      # They are sent to the enter-code path since the IdV flow does not allow
      # users to go through proofing if they are GPO pending
      expect(current_path).to eq(idv_welcome_path)
    end
  end
end
