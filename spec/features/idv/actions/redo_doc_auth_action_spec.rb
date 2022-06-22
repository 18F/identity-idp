require 'rails_helper'

feature 'doc auth cancel link sent action', js: true do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_with_barcode_warning
  end

  context 'when barcode scan returns a warning' do
    it 'returns a warning message' do
    end

    it 'contains a link in the warning message to redo docauth' do
    end

    it 'goes back to the upload image page to upload the images again' do
    end
  end
end
