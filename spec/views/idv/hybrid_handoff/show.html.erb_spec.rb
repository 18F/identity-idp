require 'rails_helper'

RSpec.describe 'idv/hybrid_handoff/show.html.erb' do
  before do
    allow(view).to receive(:current_user).and_return(@user)
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
    @idv_how_to_verify_form = Idv::HowToVerifyForm.new
    @presenter = Idv::HowToVerifyPresenter.new(
      mobile_required: true,
      selfie_check_required: true,
      passport_allowed: true,
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
        @direct_ipp_with_selfie_enabled = true
      end
      it 'displays content and link for choose ipp' do
        expect(rendered).to have_content(t('doc_auth.headings.verify_at_post_office'))
      end
    end

    describe 'when ipp is not enabled' do
      before do
        @direct_ipp_with_selfie_enabled = false
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
