require 'rails_helper'

describe 'idv/setup_errors/show.html.erb' do
  before do
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
        ),
      ),
    )
  end
end
