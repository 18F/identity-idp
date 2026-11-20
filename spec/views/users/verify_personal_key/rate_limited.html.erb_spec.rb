require 'rails_helper'

RSpec.describe 'users/verify_personal_key/rate_limited.html.erb', :freeze_time do
  include ActionView::Helpers::DateHelper

  let(:expires_at) { 10.minutes.from_now }
  let(:rate_limited_message) do
    t(
      'errors.verify_personal_key.rate_limited',
      timeout: distance_of_time_in_words(Time.zone.now, expires_at, except: :seconds),
    )
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:expires_at, expires_at)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('headings.verify_personal_key'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the heading, wait time and go back link' do
      expect(rendered).to have_css('h1', text: t('headings.verify_personal_key'))
      expect(rendered).to have_content(rate_limited_message)
      expect(rendered).to have_link(t('links.go_back'), href: account_path)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page card with the heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('headings.verify_personal_key'))
      expect(rendered).to have_css('h1', count: 1)
    end

    it 'renders the error status-icon badge with the lock icon' do
      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon--error')
      expect(rendered).to include(NDS::IconComponent.markup_for('nds/icons/lock/24.svg'))
    end

    it 'renders a divider above the wait time' do
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css('.auth__form-page-body p', text: rate_limited_message)
    end

    it 'renders go back as a button to the account page' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--secondary[href='#{account_path}']",
        text: t('links.go_back'),
      )
    end
  end
end
