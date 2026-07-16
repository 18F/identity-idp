require 'rails_helper'

RSpec.describe 'idv/hybrid_handoff/show.html.erb' do
  before do
    allow(view).to receive(:current_user).and_return(@user)
    allow(view).to receive(:sp_session).and_return(request_id: 'request-id')
    allow(controller).to receive(:idv_session).and_return(
      instance_double(Idv::Session, document_capture_session_uuid: SecureRandom.uuid),
    )
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
    @idv_how_to_verify_form = Idv::HowToVerifyForm.new
    @presenter = Idv::HowToVerifyPresenter.new(
      selfie_check_required: true,
    )
    @upload_enabled = true
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

    it 'renders a QR code for starting mobile doc auth' do
      expect(rendered).to have_css(
        'img.ads-handoff__qr-image[src^="data:image/png;base64,"]',
      )
    end

    it 'displays QR-first handoff content' do
      expect(rendered).to have_selector('h1', text: t('headings.continue_on_phone.title'))
      expect(rendered).to have_content(t('headings.continue_on_phone.qr_description_lead'))
      expect(rendered).to have_button(t('headings.continue_on_phone.text_link'))
      expect(rendered).to have_content(t('headings.continue_on_phone.qr_description_tail').strip)
    end

    it 'opens the SMS modal from the text message link' do
      expect(rendered).to have_css(
        "button.ads-link[data-ads-modal-open][aria-controls='hybrid-handoff-sms-modal']",
        text: t('headings.continue_on_phone.text_link'),
      )
      expect(rendered).to have_css('#hybrid-handoff-sms-modal', visible: :hidden)
      expect(rendered).to have_css(
        '#form-to-submit-photos-through-mobile',
        text: t('forms.buttons.send_link'),
        visible: :hidden,
      )
    end
  end

  context 'when selfie is required' do
    before do
      @selfie_required = true
      @post_office_enabled = true
    end

    it 'renders a QR code for starting mobile doc auth' do
      expect(rendered).to have_css(
        'img.ads-handoff__qr-image[src^="data:image/png;base64,"]',
      )
    end

    it 'displays the expected page heading' do
      expect(rendered).to have_selector('h1', text: t('headings.continue_on_phone.title'))
    end

    describe 'when ipp is enabled' do
      before do
        @post_office_enabled = true
      end

      it 'renders verify in person and desktop actions' do
        expect(rendered).to have_css(
          'button.ads-button--secondary',
          text: t('forms.buttons.verify_in_person'),
        )
        expect(rendered).to have_css(
          'button.ads-button--quaternary',
          text: t('forms.buttons.continue_on_desktop'),
        )
      end
    end

    describe 'when ipp is not enabled' do
      before do
        @post_office_enabled = false
      end

      it 'does not render verify in person' do
        expect(rendered).to_not have_button(t('forms.buttons.verify_in_person'))
      end
    end
  end
end
