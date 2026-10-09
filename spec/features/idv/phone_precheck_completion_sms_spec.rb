require 'rails_helper'

# A successful phone precheck completes the phone step without sending an OTP, which used to
# leave the proofing completion SMS without a phone number to send to. See LG-17798.
RSpec.feature 'phone precheck proofing completion SMS', :js do
  include IdvStepHelper
  include IdvHelper
  include DocAuthHelper

  let(:user) { user_with_2fa }

  before do
    allow(IdentityConfig.store).to receive(:idv_phone_precheck_percent).and_return(100)
    allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
  end

  it 'sends the proofing completion SMS to the precheck phone' do
    # Facial match mints the profile at an enhanced idv_level, which the SMS is gated on.
    start_idv_from_sp(:oidc, facial_match_required: true)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_ssn_step(with_selfie: true)
    complete_ssn_step

    complete_verify_step

    # The phone step is skipped entirely because the precheck passed.
    expect(page).to have_current_path(idv_enter_password_path)

    Telephony::Test::Message.clear_messages
    complete_enter_password_step(user)

    # Wait for the password submission to finish before inspecting delivered messages, otherwise
    # the assertion can race the request that sends the SMS.
    expect(page).to have_current_path(idv_personal_key_path)

    proofing_sms = Telephony::Test::Message.messages.find do |message|
      message.body.include?('Identity verified on')
    end

    expect(proofing_sms).to be_present
    expect(proofing_sms.to).to eq(user.default_phone_configuration.formatted_phone)
  end
end
