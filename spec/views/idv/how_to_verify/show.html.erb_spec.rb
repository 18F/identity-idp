require 'rails_helper'

RSpec.describe 'idv/how_to_verify/show.html.erb' do
  selection = Idv::HowToVerifyForm::IPP
  let(:selfie_check_required) { false }
  let(:presenter) do
    Idv::HowToVerifyPresenter.new(
      selfie_check_required: selfie_check_required,
    )
  end
  let(:idv_how_to_verify_form) { Idv::HowToVerifyForm.new(selection: selection) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(false)
    allow(view).to receive(:user_signing_up?).and_return(false)
    assign(:presenter, presenter)
    assign(:post_office_enabled, true)
    assign :idv_how_to_verify_form, idv_how_to_verify_form
  end
  context 'when selfie is not required' do
    let(:selfie_check_required) { false }

    before do
      @selfie_required = selfie_check_required
    end

    it 'renders a step indicator with Getting started as the current step' do
      render
      expect(view.content_for(:pre_flash_content)).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.getting_started'),
      )
    end

    it 'renders a title' do
      render
      expect(rendered).to have_content(t('doc_auth.headings.how_to_verify'))
    end

    it 'renders two options for verifying your identity' do
      render
      expect(rendered).to have_content(t('doc_auth.headings.verify_online'))
      expect(rendered).to have_content(t('doc_auth.headings.verify_at_post_office'))
    end

    it 'renders a button for remote and ipp' do
      render
      expect(rendered).to have_button(t('forms.buttons.continue_online'))
      expect(rendered).to have_button(t('forms.buttons.continue_ipp'))
    end

    it 'renders troubleshooting links' do
      render
      expect(rendered).to have_link(t('doc_auth.info.verify_online_link_text'))
      expect(rendered).to have_link(t('doc_auth.info.verify_at_post_office_link_text'))
    end

    it 'renders a cancel link' do
      render
      expect(rendered).to have_link(t('links.cancel'))
    end

    it 'renders non-selfie specific content' do
      render
      expect(rendered).to have_content(t('doc_auth.headings.verify_online'))
      expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction'))
      expect(rendered).to have_content(t('doc_auth.info.verify_online_description'))
      expect(rendered).to have_content(t('doc_auth.info.verify_at_post_office_instruction'))
      expect(rendered).to have_content(
        strip_tags(t('doc_auth.info.verify_at_post_office_description_passport_html')),
      )
    end

    context 'when in person passports is disabled' do
      it 'renders passport specific content to verify your identity online' do
        render
        expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction'))
        expect(rendered).to have_content(
          t('doc_auth.info.verify_online_description'),
        ).once
        expect(rendered).to have_content(
          strip_tags(t('doc_auth.info.verify_at_post_office_description_passport_html')),
        )
      end
    end

    context 'when in person passports is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
      end

      it 'renders passport specific content to verify your identity online and in person' do
        render

        expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction'))
        expect(rendered).to have_content(
          t('doc_auth.info.verify_online_description'),
        ).twice
        expect(rendered).not_to have_content(
          strip_tags(t('doc_auth.info.verify_at_post_office_description_passport_html')),
        )
      end
    end

    context 'when passport is allowed' do
      let(:passport_allowed) { true }

      context 'when in person passports is disabled' do
        it 'renders passport specific content to verify your identity online' do
          render
          expect(rendered).to have_content(
            t('doc_auth.info.verify_online_instruction'),
          )
          expect(rendered).to have_content(
            t('doc_auth.info.verify_online_description'),
          ).once
          expect(rendered).to have_content(
            strip_tags(t('doc_auth.info.verify_at_post_office_description_passport_html')),
          )
        end
      end

      context 'when in person passports is enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
        end

        it 'renders passport specific content to verify your identity online and in person' do
          render
          expect(rendered).to have_content(
            t('doc_auth.info.verify_online_instruction'),
          )
          expect(rendered).to have_content(
            t('doc_auth.info.verify_online_description'),
          ).twice
          expect(rendered).not_to have_content(
            strip_tags(t('doc_auth.info.verify_at_post_office_description_passport_html')),
          )
        end
      end
    end

    context 'when selfie is required' do
      let(:selfie_check_required) { true }

      it 'renders selfie specific content' do
        render
        expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction_selfie'))
        expect(rendered).to have_content(t('doc_auth.info.verify_online_description'))
        expect(rendered).to have_content(t('doc_auth.info.verify_at_post_office_instruction'))
        expect(rendered).to have_content(
          strip_tags(t('doc_auth.info.verify_at_post_office_description_passport_html')),
        )
      end

      context 'when passport is allowed' do
        let(:passport_allowed) { true }

        context 'when in person passports is disabled' do
          it 'renders passport specific content to verify your identity online' do
            render
            expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction_selfie'))
            expect(rendered).to have_content(
              t('doc_auth.info.verify_online_description'),
            ).once
            expect(rendered).to have_content(
              strip_tags(t('doc_auth.info.verify_at_post_office_description_passport_html')),
            )
          end
        end

        context 'when in person passports is enabled' do
          before do
            allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
          end
          it 'renders passport specific content to verify your identity online and in person' do
            render
            expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction_selfie'))
            expect(rendered).to have_content(
              t('doc_auth.info.verify_online_description'),
            ).twice
            expect(rendered).not_to have_content(
              strip_tags(t('doc_auth.info.verify_at_post_office_description_passport_html')),
            )
          end
        end
      end
    end
  end

  it 'does not render the NDS form-page card in the default layout' do
    render

    expect(rendered).to_not have_selector('.auth--form-page')
    expect(view.content_for(:nds_header_progress)).to be_nil
  end

  context 'in the NDS layout' do
    let(:clear1_allowed) { false }
    let(:presenter) do
      Idv::HowToVerifyPresenter.new(selfie_check_required:, clear1_allowed:)
    end

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with one heading and the online copy' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('doc_auth.headings.how_to_verify'),
      )
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: "#{t('doc_auth.info.verify_online_instruction')} " \
              "#{t('doc_auth.info.verify_online_description')}",
      )
    end

    it 'replaces the step indicator with the verification header progress' do
      render

      expect(view.content_for(:pre_flash_content)).to be_nil
      expect(view.content_for(:nds_header_progress)).to have_css(
        '.progress__step[aria-current="step"] .progress__step-counter',
        text: '3 / 12',
      )
    end

    it 'submits each option to how to verify from one form' do
      render

      form = "form[action='#{idv_how_to_verify_url}'][method='post']"
      expect(rendered).to have_css(form, count: 1)
      expect(rendered).to have_css("#{form} input[name=_method][value=put]", visible: :all)
      expect(rendered).to have_css(
        "#{form} .auth__actions button[type=submit][name='idv_how_to_verify_form[selection]']" \
          "[value='#{Idv::HowToVerifyForm::REMOTE}']:not(.usa-button--secondary)",
        text: t('forms.buttons.continue_online'),
      )
      expect(rendered).to have_css(
        "#{form} .auth__actions button.usa-button--secondary[type=submit]" \
          "[name='idv_how_to_verify_form[selection]'][value='#{Idv::HowToVerifyForm::IPP}']",
        text: t('nds.choose_id_type.verify_in_person'),
      )
      expect(rendered).to have_css('.auth__actions .separator', text: t('nds.choose_id_type.or'))
    end

    it 'renders a tertiary cancel and the learn more links' do
      render

      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{idv_cancel_path(step: 'how_to_verify')}']",
        text: t('links.cancel'),
      )
      expect(rendered).to have_css(
        '.auth__actions a.usa-button--tertiary[target=_blank]',
        text: t('doc_auth.info.verify_online_link_text'),
      )
      expect(rendered).to have_css(
        '.auth__actions a.usa-button--tertiary[target=_blank]',
        text: t('doc_auth.info.verify_at_post_office_link_text'),
      )
      expect(rendered).to_not have_content(t('doc_auth.info.verify_with_clear1_link_text'))
    end

    context 'when in person proofing is not offered' do
      before { assign(:post_office_enabled, false) }

      it 'renders only the online option' do
        render

        expect(rendered).to have_button(t('forms.buttons.continue_online'))
        expect(rendered).to_not have_button(t('nds.choose_id_type.verify_in_person'))
        expect(rendered).to_not have_css('.separator')
        expect(rendered).to_not have_content(t('doc_auth.info.verify_at_post_office_link_text'))
      end
    end

    context 'when CLEAR is offered' do
      let(:clear1_allowed) { true }

      it 'renders the CLEAR submit and learn more link' do
        render

        expect(rendered).to have_css(
          ".auth__actions button.clear1-button[type=submit]" \
            "[value='#{Idv::HowToVerifyForm::CLEAR1}']" \
            "[aria-label='#{t('forms.buttons.verify_with_clear1')}']",
        )
        expect(rendered).to have_css(
          '.auth__actions a[target=_blank]',
          text: t('doc_auth.info.verify_with_clear1_link_text'),
        )
      end
    end

    context 'with a selection error' do
      it 'renders the error in an error alert' do
        render template: 'idv/how_to_verify/show',
               locals: { error: t('doc_auth.errors.how_to_verify_form') }

        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error',
          text: t('doc_auth.errors.how_to_verify_form'),
        )
      end
    end

    context 'when selfie is required' do
      let(:selfie_check_required) { true }

      it 'renders the selfie online instruction' do
        render

        expect(rendered).to have_selector(
          '.auth__intro-description',
          text: t('doc_auth.info.verify_online_instruction_selfie'),
        )
      end
    end
  end
end
