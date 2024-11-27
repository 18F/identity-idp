require 'rails_helper'

RSpec.describe 'idv/socure/socure_errors/warning.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:remaining_submit_attempts) { 5 }
  let(:in_person_url) { nil }

  before do
    assign(:remaining_submit_attempts, remaining_submit_attempts)
    assign(:idv_in_person_url, in_person_url)
    render
  end

  it 'shows correct h1' do
    expect(rendered).to have_css('h1', text: t('idv.errors.technical_difficulties'))
  end

  it 'shows try again' do
    expect(rendered).to have_text(t('idv.errors.try_again_later'))
  end

  it 'shows remaining attempts' do
    expect(rendered).to have_text(
      strip_tags(t('idv.failure.warning.attempts_html', count: remaining_submit_attempts)),
    )
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(
      t('idv.failure.button.warning'),
      href: idv_socure_document_capture_path,
    )
  end

  context 'In person verification disabled' do
    it 'does not render link to in person flow' do
      expect(rendered).not_to have_link(
        t('idv.troubleshooting.options.verify_by_mail'),
        href: idv_in_person_url,
      )
    end
  end

  context 'In person verification enabled' do
    let(:in_person_url) { 'http://idp.test/idv/in_person' }

    it 'has an h2' do
      expect(rendered).to have_css('h2', text: t('in_person_proofing.headings.cta'))
    end

    it 'explains in person verification' do
      expect(rendered).to have_text(t('in_person_proofing.body.cta.prompt_detail'))
    end

    it 'has a secondary cta' do
      expect(rendered).to have_link(t('in_person_proofing.body.cta.button'), href: in_person_url)
    end
  end
end
