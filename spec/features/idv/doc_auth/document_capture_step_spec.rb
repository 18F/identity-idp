require 'rails_helper'

feature 'document cpature step' do
  include IdvStepHelper
  include DocAuthHelper

  context 'when the step is enabled' do
    before do
      allow(Figaro.env).to receive(:document_capture_step_enabled).and_return('true')
    end

    it 'is on the right step' do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step

      expect(current_path).to eq(idv_doc_auth_document_capture_step)
    end
  end

  context 'when the step is disabled' do
    before do
      allow(Figaro.env).to receive(:document_capture_step_enabled).and_return('false')
    end

    it 'takes the user to the front image step' do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step

      expect(current_path).to eq(idv_doc_auth_front_image_step)
    end
  end
end
