require 'rails_helper'

feature 'doc auth v2' do
  include IdvStepHelper
  include DocAuthHelper

  let(:user) { create(:user, :signed_up) }

  before do
    enable_doc_auth
  end

  it 'works' do
    sign_in_and_2fa_user(user)
    complete_doc_auth_v2_steps
  end
end
