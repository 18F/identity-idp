require 'rails_helper'

RSpec.describe 'idv/how_to_verify/show.html.erb' do
  selection = Idv::HowToVerifyForm::IPP
  let(:mobile_required) { false }
  let(:selfie_check_required) { false }
  let(:presenter) do
    Idv::HowToVerifyPresenter.new(
      mobile_required: mobile_required,
      selfie_check_required: selfie_check_required,
    )
  end
  let(:idv_how_to_verify_form) { Idv::HowToVerifyForm.new(selection: selection) }

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    assign(:presenter, presenter)
    assign :idv_how_to_verify_form, idv_how_to_verify_form
  end
  context 'when mobile is not required' do
    before do
      @mobile_required = mobile_required
      @selfie_required = selfie_check_required
      render
    end

    it 'renders a step indicator with Getting started as the current step' do
      expect(view.content_for(:pre_flash_content)).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.getting_started'),
      )
    end

    it 'renders a title' do
      expect(rendered).to have_content(t('doc_auth.headings.how_to_verify'))
    end

    it 'renders two options for verifying your identity' do
      expect(rendered).to have_content(t('doc_auth.headings.verify_online'))
      expect(rendered).to have_content(t('doc_auth.headings.verify_at_post_office'))
    end

    it 'renders a button for remote and ipp' do
      expect(rendered).to have_button(t('forms.buttons.continue_remote'))
      expect(rendered).to have_button(t('forms.buttons.continue_ipp'))
    end

    it 'renders a troubleshooting section' do
      expect(rendered).to have_content(
        t('doc_auth.info.how_to_verify_troubleshooting_options_header'),
      )
      expect(rendered).to have_link(t('doc_auth.info.verify_online_link_text'))
      expect(rendered).to have_link(t('doc_auth.info.verify_at_post_office_link_text'))
    end

    it 'renders a cancel link' do
      expect(rendered).to have_link(t('links.cancel'))
    end

    it 'renders non-selfie specific content' do
      expect(rendered).to have_content(t('doc_auth.info.how_to_verify'))
      expect(rendered).not_to have_content(t('doc_auth.tips.mobile_phone_required'))
      expect(rendered).to have_content(t('doc_auth.headings.verify_online'))
      expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction'))
      expect(rendered).to have_content(t('doc_auth.info.verify_online_description'))
      expect(rendered).to have_content(t('doc_auth.info.verify_at_post_office_instruction'))
      expect(rendered).to have_content(t('doc_auth.info.verify_at_post_office_description'))
    end
  end

  context 'when mobile is required' do
    let(:selfie_check_required) { false }
    let(:mobile_required) { true }

    before do
      @selfie_required = selfie_check_required
      @mobile_required = mobile_required
      render
    end

    it 'renders a step indicator with Getting started as the current step' do
      expect(view.content_for(:pre_flash_content)).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.getting_started'),
      )
    end

    it 'renders a title' do
      expect(rendered).to have_content(t('doc_auth.headings.how_to_verify'))
    end

    it 'renders two options for verifying your identity' do
      expect(rendered).to have_content(t('doc_auth.headings.verify_online_mobile'))
      expect(rendered).to have_content(t('doc_auth.headings.verify_at_post_office'))
    end

    it 'renders a button for remote and ipp' do
      expect(rendered).to have_button(t('forms.buttons.continue_remote_mobile'))
      expect(rendered).to have_button(t('forms.buttons.continue_ipp'))
    end

    it 'renders a troubleshooting section' do
      expect(rendered).to have_content(
        t('doc_auth.info.how_to_verify_troubleshooting_options_header'),
      )
      expect(rendered).to have_link(t('doc_auth.info.verify_online_link_text'))
      expect(rendered).to have_link(t('doc_auth.info.verify_at_post_office_link_text'))
    end

    it 'renders a cancel link' do
      expect(rendered).to have_link(t('links.cancel'))
    end

    it 'renders mobile specific content' do
      expect(rendered).to have_content(
        t('doc_auth.info.verify_online_instruction_mobile_no_selfie'),
      )
    end

    context 'when selfie is required' do
      let(:selfie_check_required) { true }

      it 'renders selfie specific content' do
        expect(rendered).to have_content(t('doc_auth.info.how_to_verify_mobile'))
        expect(rendered).to have_content(t('doc_auth.tips.mobile_phone_required'))
        expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction_selfie'))
        expect(rendered).to have_content(t('doc_auth.info.verify_online_description_mobile'))
        expect(rendered).to have_content(
          t('doc_auth.info.verify_at_post_office_instruction_selfie'),
        )
        expect(rendered).to have_content(
          t('doc_auth.info.verify_at_post_office_description_mobile'),
        )
      end
    end
  end
end
