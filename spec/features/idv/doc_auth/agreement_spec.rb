require 'rails_helper'

RSpec.feature 'agreement step error checking' do
  include DocAuthHelper
  context 'skipping hybrid_handoff step', :js, driver: :headless_chrome_mobile do
    let(:fake_analytics) { FakeAnalytics.new }

    before do
      allow_any_instance_of(ApplicationController).
        to receive(:analytics).and_return(fake_analytics)

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
      complete_agreement_step
    end

    it 'progresses to document capture' do
      expect(page).to have_current_path(idv_document_capture_url)
    end
  end
end
