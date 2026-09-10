require 'rails_helper'

RSpec.describe 'idv/please_call/show.html.erb' do
  let(:in_person_proofing_enabled) { false }
  let(:in_person) { false }
  let(:nds_layout) { false }
  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    @call_by_date = Date.new(2023, 10, 13)
    @in_person = in_person
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled)
      .and_return(in_person_proofing_enabled)
    render
  end

  it 'shows step indicator with pending status on secure account' do
    expect(view.content_for(:pre_flash_content)).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.re_enter_password'),
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

  context 'ipp enabled' do
    let(:in_person_proofing_enabled) { true }
    let(:in_person) { true }

    it 'does not show step indicator secure account' do
      expect(view.content_for(:pre_flash_content)).not_to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.secure_account'),
      )
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the verification header progress instead of the step indicator' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
      expect(view.content_for(:pre_flash_content)).to be_nil
    end

    it 'renders the call-by date and the contact sentence with a tel: link and inline code' do
      expect(rendered).to have_css('.auth__form-page-body strong', text: 'October 13, 2023')
      expect(rendered).to have_css("a.text-no-wrap[href='tel:8445555555']", text: '(844) 555-5555')
      expect(rendered).to have_css('p .field-readout--inline .field-readout__value', text: 'ABCD')
    end

    context 'in person' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person) { true }

      it 'does not render header progress' do
        expect(view.content_for(:nds_header_progress)).to be_nil
      end
    end
  end
end
