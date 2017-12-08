require 'rails_helper'

describe 'verify/review/new.html.slim' do
  include XPathHelper

  context 'user has completed all steps' do
    before do
      user = build_stubbed(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)
      @idv_params = {
        first_name: 'Some',
        last_name: 'One',
        ssn: '666-66-1234',
        ccn: '12345678',
        dob: Date.parse('1972-03-29'),
        address1: '123 Main St',
        city: 'Somewhere',
        state: 'MO',
        zipcode: '12345',
        phone: '+1 (213) 555-0000',
      }

      render
    end

    it 'renders all steps' do
      expect(rendered).to have_content('Some One')
      expect(rendered).to have_content('123 Main St')
      expect(rendered).to have_content('Somewhere')
      expect(rendered).to have_content('MO')
      expect(rendered).to have_content('12345')
      expect(rendered).to have_content('666-66-1234')
      expect(rendered).to have_content('+1 (213) 555-0000')
      expect(rendered).to have_content('March 29, 1972')
    end

    it 'renders the correct content heading' do
      expect(rendered).to have_content t('idv.titles.session.review')
    end

    it 'contains an accordion with verified user information' do
      accordion_selector = generate_class_selector('accordion')
      expect(rendered).to have_xpath("//#{accordion_selector}")
    end

    it 'renders the correct header for the accordion' do
      expect(rendered).to have_content(t('idv.messages.review.intro'))
    end
  end
end
