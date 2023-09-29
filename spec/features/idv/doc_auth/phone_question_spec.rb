require 'rails_helper'

RSpec.feature 'phone question step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
  end

  context 'on a desktop device send link' do
    before do
      complete_doc_auth_steps_before_hybrid_handoff_step
      visit(idv_phone_question_url)
    end

    it 'contains phone question header' do
      expect(page).to have_content(t('doc_auth.headings.phone_question'))
    end

    it 'contains option to confirm having phone' do
      expect(page).to have_content(t('doc_auth.buttons.have_phone'))
    end

    it 'contains option to confirm not having phone' do
      expect(page).to have_content(t('doc_auth.phone_question.do_not_have'))
    end
  end
end
