require 'rails_helper'

RSpec.describe 'idv/hybrid_handoff/show.html.erb' do
  before do
    allow(view).to receive(:current_user).and_return(@user)
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
  end

  subject(:rendered) do
    render template: 'idv/hybrid_handoff/show', locals: {
      idv_phone_form: @idv_form,
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

    it 'has a form for starting desktop doc auth with an aria label tag' do
      expect(rendered).to have_selector(
        :xpath,
        "//form[@aria-label=\"#{t('forms.buttons.upload_photos')}\"]",
      )
    end

    it 'displays the expected headings from the "a" case' do
      expect(rendered).to have_selector('h1', text: t('doc_auth.headings.hybrid_handoff'))
      expect(rendered).to have_selector('h2', text: t('doc_auth.headings.upload_from_phone'))
    end

    it 'does not display IPP related content' do
      expect(rendered).to_not have_content(strip_tags(t('doc_auth.info.hybrid_handoff_ipp_html')))
      expect(rendered).to_not have_link(
        t('in_person_proofing.headings.prepare'),
        href: idv_document_capture_path(step: :hybrid_handoff),
      )
    end
  end
  context 'when selfie is required' do
    before do
      @selfie_required = true
    end
    it 'has a form for starting mobile doc auth with an aria label tag' do
      expect(rendered).to have_selector(
        :xpath,
        "//form[@aria-label=\"#{t('forms.buttons.send_link')}\"]",
      )
    end
    it 'displays the expected headings from the "a" case' do
      expect(rendered).to have_selector('h1', text: t('doc_auth.headings.hybrid_handoff_selfie'))
    end

    describe 'when ipp is enabled' do
      before do
        @direct_ipp_with_selfie_enabled = true
      end
      it 'displays content and link for choose ipp' do
        expect(rendered).to have_content(strip_tags(t('doc_auth.info.hybrid_handoff_ipp_html')))
        expect(rendered).to have_link(
          t('in_person_proofing.headings.prepare'),
          href: idv_document_capture_path(step: :hybrid_handoff),
        )
      end
    end

    describe 'when ipp is not enabled' do
      before do
        @direct_ipp_with_selfie_enabled = false
      end
      it 'displays content and link for choose ipp' do
        expect(rendered).to_not have_content(strip_tags(t('doc_auth.info.hybrid_handoff_ipp_html')))
        expect(rendered).to_not have_link(
          t('in_person_proofing.headings.prepare'),
          href: idv_document_capture_path(step: :hybrid_handoff),
        )
      end
    end
  end
end
