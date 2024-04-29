require 'rails_helper'

RSpec.describe 'idv/how_to_verify/show.html.erb' do
  selection = Idv::HowToVerifyForm::IPP
  let(:idv_how_to_verify_form) do
    Idv::HowToVerifyForm.new(selection: selection)
  end

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    assign :idv_how_to_verify_form, idv_how_to_verify_form
  end
  context 'when selfie is not required' do
    before do
      @selfie_required = false
      render
    end

    context 'renders the show template with' do
      it 'a title' do
        expect(rendered).to have_content(t('doc_auth.headings.how_to_verify'))
      end

      it 'two options for verifying your identity' do
        expect(rendered).to have_content(t('doc_auth.headings.verify_online'))
        expect(rendered).to have_content(t('doc_auth.headings.verify_at_post_office'))
      end

      it 'a button for remote and ipp' do
        expect(rendered).to have_button(t('forms.buttons.continue_remote'))
        expect(rendered).to have_button(t('forms.buttons.continue_ipp'))
      end

      it 'a troubleshooting section' do
        expect(rendered).to have_content(
          t('doc_auth.info.how_to_verify_troubleshooting_options_header'),
        )
        expect(rendered).to have_link(t('doc_auth.info.verify_online_link_text'))
        expect(rendered).to have_link(t('doc_auth.info.verify_at_post_office_link_text'))
      end

      it 'a cancel link' do
        expect(rendered).to have_link(t('links.cancel'))
      end

      it 'non-selfie specific content' do
        expect(rendered).to have_content(t('doc_auth.info.how_to_verify'))
        expect(rendered).not_to have_content(t('doc_auth.tips.mobile_phone_required'))
        expect(rendered).to have_content(t('doc_auth.headings.verify_online'))
        expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction'))
        expect(rendered).to have_content(t('doc_auth.info.verify_online_description'))
        expect(rendered).to have_content(t('doc_auth.info.verify_at_post_office_instruction'))
        expect(rendered).to have_content(t('doc_auth.info.verify_at_post_office_description'))
      end
    end
  end

  context 'when selfie is required' do
    before do
      @selfie_required = true
      render
    end

    context 'renders the show template with' do
      it 'a title' do
        expect(rendered).to have_content(t('doc_auth.headings.how_to_verify'))
      end

      it 'two options for verifying your identity' do
        expect(rendered).to have_content(t('doc_auth.headings.verify_online_selfie'))
        expect(rendered).to have_content(t('doc_auth.headings.verify_at_post_office'))
      end

      it 'a button for remote and ipp' do
        expect(rendered).to have_button(t('forms.buttons.continue_remote_selfie'))
        expect(rendered).to have_button(t('forms.buttons.continue_ipp'))
      end

      it 'a troubleshooting section' do
        expect(rendered).to have_content(
          t('doc_auth.info.how_to_verify_troubleshooting_options_header'),
        )
        expect(rendered).to have_link(t('doc_auth.info.verify_online_link_text'))
        expect(rendered).to have_link(t('doc_auth.info.verify_at_post_office_link_text'))
      end

      it 'a cancel link' do
        expect(rendered).to have_link(t('links.cancel'))
      end

      it 'selfie specific content' do
        expect(rendered).to have_content(t('doc_auth.info.how_to_verify_selfie'))
        expect(rendered).to have_content(t('doc_auth.tips.mobile_phone_required'))
        expect(rendered).to have_content(t('doc_auth.info.verify_online_instruction_selfie'))
        expect(rendered).to have_content(t('doc_auth.info.verify_online_description_selfie'))
        expect(rendered).to have_content(
          t('doc_auth.info.verify_at_post_office_instruction_selfie'),
        )
        expect(rendered).to have_content(
          t('doc_auth.info.verify_at_post_office_description_selfie'),
        )
      end
    end
  end
end
