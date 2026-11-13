require 'rails_helper'

RSpec.describe 'idv/hybrid_handoff/show.html.erb' do
  let(:clear1_allowed) { false }
  let(:nds_layout) { false }
  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:current_user).and_return(@user)
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
    @idv_how_to_verify_form = Idv::HowToVerifyForm.new
    @presenter = Idv::HowToVerifyPresenter.new(
      selfie_check_required: true,
      clear1_allowed:,
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

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('doc_auth.headings.how_to_verify'))

    rendered
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
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
        expect(rendered).to_not have_content(
          strip_tags(t('doc_auth.headings.verify_at_post_office')),
        )
      end
    end

    it 'does not render the Clear1 action' do
      expect(rendered).not_to have_selector('#form-to-verify-with-clear1')
      expect(rendered).not_to have_content(t('doc_auth.headings.verify_with_existing_account'))
    end

    context 'when clear1 is enabled' do
      let(:clear1_allowed) { true }

      it 'renders the Clear1 action as designed' do
        expect(rendered).to have_selector(
          :xpath,
          "//form[@aria-label=\"#{t('forms.buttons.verify_with_clear1')}\"]",
        )
        expect(rendered).to have_selector(
          'h2',
          text: t('doc_auth.headings.verify_with_existing_account'),
        )
        expect(rendered).to have_content(t('doc_auth.info.verify_with_clear1'))
        expect(rendered).to have_link(t('doc_auth.info.verify_with_clear1_link_text'))
        expect(rendered).to have_button(t('forms.buttons.verify_with_clear1'))
        expect(rendered).to have_selector(
          "input[name='idv_how_to_verify_form[selection]']" \
          "[value='#{Idv::HowToVerifyForm::CLEAR1}']",
          visible: :all,
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
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }
    let(:progress) { Capybara.string(view.content_for(:nds_header_progress)) }
    let(:selection_name) { 'idv_how_to_verify_form[selection]' }
    let(:secondary_submit) { '.auth__actions button.usa-button--secondary[formnovalidate]' }
    let(:country_radio) { "input[type=radio][name='doc_auth[international_code]']" }

    def help_link_url(article:, step:)
      help_center_redirect_path(
        category: 'verify-your-identity',
        article:,
        flow: :idv,
        step:,
        location: 'troubleshooting_options',
      )
    end

    before { @selfie_required = false }

    it 'renders the phone card with send-link primary and cancel tertiary actions' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('nds.hybrid_handoff.heading'))
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.hybrid_handoff.subtitle'),
      )
      expect(rendered).to have_css('form[data-nds-submit-gate] .usa-phone-input')
      expect(rendered).to have_selector(
        :xpath,
        "//form[@aria-label=\"#{t('forms.buttons.send_link')}\"]",
      )
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]:not(.usa-button--secondary)',
        text: t('forms.buttons.send_link'),
      )
      expect(rendered).to have_link(
        t('links.cancel'),
        href: idv_cancel_path(step: 'hybrid_handoff'),
      )
    end

    it 'sets the verification header progress to the hybrid handoff substep' do
      rendered
      expect(progress).to have_css('nds-progress .progress__step[aria-current="step"]')
      expect(progress).to have_css('.progress__step-counter', text: '3 / 12')
    end

    it 'offers no alternatives by default' do
      expect(rendered).not_to have_css('.separator')
      expect(rendered).not_to have_button(t('forms.buttons.verify_with_clear1'))
      expect(rendered).not_to have_button(t('nds.choose_id_type.verify_in_person'))
      expect(rendered).not_to have_button(t('doc_auth.headings.upload_from_computer'))
    end

    it 'does not render the legacy markup' do
      expect(rendered).not_to have_content(t('doc_auth.headings.how_to_verify'))
      expect(rendered).not_to have_content(t('doc_auth.headings.upload_from_phone'))
    end

    it 'links to online verification help in a new tab' do
      url = help_link_url(article: 'overview', step: :how_to_verify)
      expect(rendered).to have_css(
        ".nds-troubleshooting-options a[target=_blank][href='#{url}']",
        text: t('doc_auth.info.verify_online_link_text'),
      )
      expect(rendered).not_to have_link(t('doc_auth.info.verify_at_post_office_link_text'))
      expect(rendered).not_to have_link(t('doc_auth.info.verify_with_clear1_link_text'))
    end

    describe 'country picker' do
      context 'with countries that support SMS' do
        it 'lists them' do
          expect(rendered).to have_css("#{country_radio}[value=US]", visible: :all)
          expect(rendered).to have_css("#{country_radio}[value=GB]", visible: :all)
        end
      end

      context 'with a country that supports SMS only to confirmed phones' do
        it 'lists it, as the legacy phone input does' do
          expect(rendered).to have_css("#{country_radio}[value=AF]", visible: :all)
        end
      end

      context 'with a country that has no SMS support' do
        it 'does not list it' do
          expect(rendered).not_to have_css("#{country_radio}[value=AE]", visible: :all)
        end
      end
    end

    context 'when clear1 is enabled' do
      let(:clear1_allowed) { true }

      it 'offers CLEAR as a submit that skips phone validation' do
        expect(rendered).to have_css('.auth__actions .separator', text: t('nds.choose_id_type.or'))
        expect(rendered).to have_css(
          ".auth__actions button.clear1-button[formnovalidate][name='#{selection_name}']" \
          "[value='#{Idv::HowToVerifyForm::CLEAR1}']",
        )
        expect(rendered).to have_button(t('forms.buttons.verify_with_clear1'))
      end

      it 'links to CLEAR help in a new tab' do
        url = help_link_url(article: 'overview', step: :hybrid_handoff)
        expect(rendered).to have_css(
          ".nds-troubleshooting-options a[target=_blank][href='#{url}']",
          text: t('doc_auth.info.verify_with_clear1_link_text'),
        )
      end
    end

    context 'when in-person proofing is available' do
      before { @post_office_enabled = true }

      it 'offers verify in person as a secondary submit' do
        expect(rendered).to have_css('.auth__actions .separator', text: t('nds.choose_id_type.or'))
        expect(rendered).to have_css(
          "#{secondary_submit}[name='#{selection_name}'][value='#{Idv::HowToVerifyForm::IPP}']",
          text: t('nds.choose_id_type.verify_in_person'),
        )
      end

      it 'links to in-person verification help in a new tab' do
        url = help_link_url(article: 'verify-your-identity-in-person', step: :how_to_verify)
        expect(rendered).to have_css(
          ".nds-troubleshooting-options a[target=_blank][href='#{url}']",
          text: t('doc_auth.info.verify_at_post_office_link_text'),
        )
      end
    end

    context 'with desktop upload enabled' do
      before { @upload_enabled = true }

      it 'offers continue-on-this-computer as a secondary submit to the desktop path' do
        expect(rendered).to have_css(
          "#{secondary_submit}[formaction='#{url_for(type: :desktop)}']",
          text: t('doc_auth.headings.upload_from_computer'),
        )
      end
    end
  end
end
