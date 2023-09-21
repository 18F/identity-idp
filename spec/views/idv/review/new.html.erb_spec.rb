require 'rails_helper'

RSpec.describe 'idv/review/new.html.erb' do
  include XPathHelper

  context 'user has completed all steps' do
    let(:dob) { '1972-03-29' }

    before do
      user = build_stubbed(:user, :fully_registered)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:step_indicator_steps).
        and_return(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS)
      allow(view).to receive(:step_indicator_step).and_return(:secure_account)
    end

    context 'user goes through phone finder' do
      before do
        @title = t('titles.idv.review')
        @heading = t('idv.titles.session.review', app_name: APP_NAME)
        render
      end

      it 'has a localized title' do
        expect(view).to receive(:title).with(t('titles.idv.review'))

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

    context 'user goes through verify by mail flow' do
      before do
        @title = t('titles.idv.review_letter')
        @heading = t('idv.titles.session.review_letter', app_name: APP_NAME)
        render
      end

      it 'has a localized title' do
        expect(view).to receive(:title).with(t('titles.idv.review_letter'))

        render
      end

      it 'renders the correct content heading' do
        expect(rendered).to have_content t('idv.titles.session.review_letter', app_name: APP_NAME)
      end
    end
  end
end
