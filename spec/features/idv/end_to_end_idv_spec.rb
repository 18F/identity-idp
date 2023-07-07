require 'rails_helper'

RSpec.describe 'Identity verification', :js do
  # check if these are all needed
  include IdvHelper
  include DocAuthHelper
  include SamlAuthHelper
  include WebAuthnHelper

  scenario 'Unsupervised proofing happy path' do
    visit_idp_from_sp_with_ial2(:oidc)
    sign_up_and_2fa_ial1_user
    expect(page).to have_current_path(idv_welcome_path)
  end
end
