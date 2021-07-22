require 'rails_helper'

describe 'idv/review/new.html.erb' do
  include XPathHelper

  context 'user has completed all steps' do
    before do
      user = build_stubbed(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)
      @applicant = {
        first_name: 'Some',
        last_name: 'One',
        ssn: '666-66-1234',
        dob: Date.parse('1972-03-29'),
        address1: '123 Main St',
        city: 'Somewhere',
        state: 'MO',
        zipcode: '12345',
        phone: '+1 (213) 555-0000',
      }
      @step_indicator_steps = Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS

      render
    end

    it 'renders all steps' do
      expect(rendered).to have_content('Some One')
      expect(rendered).to have_content('123 Main St')
      expect(rendered).to have_content('Somewhere')
      expect(rendered).to have_content('MO')
      expect(rendered).to have_content('12345')
      expect(rendered).to have_content('666-66-1234')
      expect(rendered).to have_content('+1 213-555-0000')
      expect(rendered).to have_content('March 29, 1972')
    end

    it 'renders the correct content heading' do
      expect(rendered).to have_content t('idv.titles.session.review')
    end

    it 'contains an accordion with verified user information' do
      accordion_selector = generate_class_selector('usa-accordion')
      expect(rendered).to have_xpath("//#{accordion_selector}")
    end

    it 'renders the correct header for the accordion' do
      expect(rendered).to have_content(t('idv.messages.review.intro'))
    end

    it 'shows the step indicator' do
      expect(view.content_for(:pre_flash_content)).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.secure_account'),
      )
    end
  end
end
