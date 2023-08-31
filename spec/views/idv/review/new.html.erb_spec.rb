require 'rails_helper'

describe 'idv/review/new.html.erb' do
  include XPathHelper

  context 'user has completed all steps' do
    let(:dob) { '1972-03-29' }

    before do
      user = build_stubbed(:user, :fully_registered)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:step_indicator_steps).
        and_return(Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS)
      allow(view).to receive(:step_indicator_step).and_return(:secure_account)

      render
    end

    it 'renders the correct content heading' do
      expect(rendered).to have_content t('idv.titles.session.review', app_name: APP_NAME)
    end

    it 'shows the step indicator' do
      expect(view.content_for(:pre_flash_content)).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.secure_account'),
      )
    end
  end
end
