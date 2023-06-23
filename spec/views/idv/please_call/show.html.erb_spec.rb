require 'rails_helper'

RSpec.describe 'idv/please_call/show.html.erb' do
  before do
    @call_by_date = Date.new(2023, 10, 13)
    render
  end

  it 'shows step indicator with pending status on secure account' do
    expect(view.content_for(:pre_flash_content)).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.secure_account'),
    )
  end

  it 'includes a message instructing them to fill out a contact form' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'idv.failure.setup.fail_html',
          support_code: 'ABCD',
          contact_number: '(844) 555-5555',
        ),
      ),
    )
  end
end
