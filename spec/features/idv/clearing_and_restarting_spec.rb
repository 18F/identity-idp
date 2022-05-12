require 'rails_helper'

describe 'clearing IdV and restarting' do
  include IdvStepHelper

  let(:user) { user_with_2fa }

  context 'during GPO otp verification', js: true do
    before do
      start_idv_from_sp
      complete_idv_steps_with_gpo_before_confirmation_step(user)
      acknowledge_and_confirm_personal_key
    end

    context 'before signing out' do
      before do
        visit idv_gpo_verify_path
      end

      it_behaves_like 'clearing and restarting idv'
    end

    context 'after signing out' do
      before do
        visit account_path
        first(:link, t('links.sign_out')).click
        start_idv_from_sp
        sign_in_live_with_2fa(user)
      end

      it_behaves_like 'clearing and restarting idv'
    end
  end
end
