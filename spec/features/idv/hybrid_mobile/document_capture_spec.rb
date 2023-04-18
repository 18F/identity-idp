require 'rails_helper'

feature 'hybrid mobile document capture', js: true do
  include IdvStepHelper

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_hybrid_mobile_controllers_enabled).
      and_return(true)
  end

  let(:link_sent_via_sms) do
    link = nil

    # Intercept the link being SMS'd to the user.
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      link = config[:link]
      impl.call(**config)
    end

    sign_in_and_2fa_user
    complete_doc_auth_steps_before_upload_step
    click_send_link

    link
  end

  it 'works' do
    visit link_sent_via_sms

    attach_and_submit_images

    expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
  end
end
