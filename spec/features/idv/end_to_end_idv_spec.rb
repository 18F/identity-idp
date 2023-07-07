require 'rails_helper'

RSpec.describe 'Identity verification', :js do
  # check if these are all needed
  include IdvHelper
  include DocAuthHelper
  include SamlAuthHelper
  include WebAuthnHelper

  scenario 'Unsupervised proofing happy path desktop' do
    visit_idp_from_sp_with_ial2(:oidc)
    sign_up_and_2fa_ial1_user

    validate_welcome_page
    complete_welcome_step

    validate_agreement_page
    complete_agreement_step
  end

  def validate_welcome_page
    expect(page).to have_current_path(idv_welcome_path)

    # Check for expected content
    expect(page).to have_content(t('step_indicator.flows.idv.getting_started'))
  end

  def validate_agreement_page
    expect(page).to have_current_path(idv_agreement_path)

    # Check for expected content
    expect(page).to have_content(t('step_indicator.flows.idv.getting_started'))

    # Check for actions that shouldn't advance the user
    # Try to continue with unchecked checkbox
    click_continue
    expect(page).to have_current_path(idv_agreement_path)
    expect(page).to have_content(t('forms.validation.required_checkbox'))
  end
end
