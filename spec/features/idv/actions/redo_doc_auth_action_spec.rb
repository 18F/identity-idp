require 'rails_helper'

feature 'doc auth cancel link sent action', js: true do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_with_barcode_warning
  end

  context 'when barcode scan returns a warning' do
    it 'shows a warning message to allow the user to return to upload new images' do
    end
  end
end
