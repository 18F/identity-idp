require 'rails_helper'

RSpec.describe 'idv/how_to_verify/show.html.erb' do
  selection = Idv::HowToVerifyForm::IPP
  let(:idv_how_to_verify_form) do
    Idv::HowToVerifyForm.new(selection: selection)
  end

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)

    assign :idv_how_to_verify_form, idv_how_to_verify_form
    render
  end

  context 'renders the show template with' do
    it 'a title and info text' do
      expect(rendered).to have_content(t('doc_auth.headings.how_to_verify'))
      expect(rendered).to have_content(t('doc_auth.info.how_to_verify'))
    end

    it 'two options for verifying your identity' do
      expect(rendered).to have_content(t('doc_auth.headings.verify_online'))
      expect(rendered).to have_content(t('doc_auth.headings.verify_at_post_office'))
    end

    it 'a continue button' do
      expect(rendered).to have_button(t('forms.buttons.continue'))
    end

    it 'a troubleshooting section' do
      expect(rendered).to have_content(
       t('doc_auth.info.how_to_verify_troubleshooting_options_header'))
      expect(rendered).to have_link(t('doc_auth.info.verify_online_link_text'))
      expect(rendered).to have_link(t('doc_auth.info.verify_at_post_office_link_text'))
    end

    it 'a cancel link' do
      expect(rendered).to have_link(t('links.cancel'))
    end
  end
end
