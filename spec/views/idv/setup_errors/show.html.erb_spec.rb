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

  context 'when threatmetrix_mock_contact_url is enabled' do
    let(:mock_url) { 'https://example.com/contact' }
    before :each do
      allow(IdentityConfig.store).
        to receive(:lexisnexis_threatmetrix_mock_contact_url).
        and_return(mock_url)
    end

    it 'includes a message instructing them to fill out a mock contact form' do
      expect(rendered).to have_text(
        strip_tags(
          t('idv.failure.setup.fail_html', contact_form: mock_url),
        ),
      )
    end
  end

  context 'when threatmetrix_mock_contact_url is not present' do
    it 'includes a message instructing them to fill out a contact form' do
      expect(rendered).to have_text(
        strip_tags(
          t('idv.failure.setup.fail_html', contact_form: MarketingSite.contact_url),
        ),
      )
    end
  end
end
