require 'rails_helper'

RSpec.describe 'idv/hybrid_handoff/show.html.erb' do
  let(:clear1_enabled) { false }
  let(:nds_layout) { false }
  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:current_user).and_return(@user)
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
    @idv_how_to_verify_form = Idv::HowToVerifyForm.new
    @presenter = Idv::HowToVerifyPresenter.new(
      selfie_check_required: true,
      clear1_enabled:,
    )
  end

  subject(:rendered) do
    render template: 'idv/hybrid_handoff/show', locals: {
      idv_phone_form: @idv_form,
      idv_how_to_verify_form: @idv_how_to_verify_form,
      post_office_enabled: @post_office_enabled,
      selfie_required: @selfie_required,
      presenter: @presenter,
    }
  end

  context 'when selfie is not required' do
    before do
      @selfie_required = false
    end
    it 'has a form for starting mobile doc auth with an aria label tag' do
      expect(rendered).to have_selector(
        :xpath,
        "//form[@aria-label=\"#{t('forms.buttons.send_link')}\"]",
      )
    end

    it 'displays the expected headings from the "a" case' do
      expect(rendered).to have_selector('h1', text: t('doc_auth.headings.how_to_verify'))
      expect(rendered).to have_selector('h2', text: t('doc_auth.headings.upload_from_phone'))
    end

    it 'does not display IPP related content' do
      expect(rendered).to_not have_content(strip_tags(t('doc_auth.headings.verify_at_post_office')))
    end
  end

  it 'does not render the Clear1 action' do
    expect(rendered).not_to have_selector(
      :xpath,
      '//form[@aria-label="Clear1"]',
    )
  end

  context 'when clear1 is enabled' do
    let(:clear1_enabled) { true }
    it 'renders the Clear1 action' do
      expect(rendered).to have_selector(
        :xpath,
        '//form[@aria-label="Clear1"]',
      )
    end
  end

  context 'when selfie is required' do
    before do
      @selfie_required = true
      @post_office_enabled = true
    end
    it 'has a form for starting mobile doc auth with an aria label tag' do
      expect(rendered).to have_selector(
        :xpath,
        "//form[@aria-label=\"#{t('forms.buttons.send_link')}\"]",
      )
    end
    it 'displays the expected headings from the "a" case' do
      expect(rendered).to have_selector('h1', text: t('doc_auth.headings.how_to_verify'))
    end

    describe 'when ipp is enabled' do
      before do
        @post_office_enabled = true
      end
      it 'displays content and link for choose ipp' do
        expect(rendered).to have_content(t('doc_auth.headings.verify_at_post_office'))
      end
    end

    describe 'when ipp is not enabled' do
      before do
        @post_office_enabled = false
      end
      it 'displays content and link for choose ipp' do
        expect(rendered).to_not have_content(t('doc_auth.headings.verify_at_post_office'))
        expect(rendered).to_not have_link(
          t('in_person_proofing.headings.prepare'),
          href: idv_document_capture_path(step: :hybrid_handoff),
        )
      end
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    before { @selfie_required = false }

    it 'renders the phone card with send-link primary and cancel tertiary actions' do
      expect(rendered).to have_css('.auth--form-page h1', text: t('nds.hybrid_handoff.heading'))
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.hybrid_handoff.subtitle'),
      )
      expect(rendered).to have_css('.usa-phone-input')
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]:not(.usa-button--secondary)',
        text: t('forms.buttons.send_link'),
      )
      expect(rendered).to have_link(
        t('links.cancel'),
        href: idv_cancel_path(step: 'hybrid_handoff'),
      )
    end

    it 'sets the verification header progress' do
      rendered
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
    end

    it 'does not offer in-person verification or desktop upload by default' do
      expect(rendered).not_to have_content(t('doc_auth.headings.upload_from_computer'))
      expect(rendered).not_to have_field('idv_how_to_verify_form[selection]', type: :hidden)
    end

    context 'with desktop upload enabled' do
      before { @upload_enabled = true }

      it 'offers continue-on-this-computer as a secondary submit' do
        expect(rendered).to have_css(
          '.auth__actions button.usa-button--secondary[formnovalidate]',
          text: t('doc_auth.headings.upload_from_computer'),
        )
      end
    end
  end
end
