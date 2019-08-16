class TwilioVoiceController < ApplicationController
  skip_before_action :verify_authenticity_token

  # In config/application.rb we have configured the TwilioWebhookAuthentication
  # on this endpoint. This means that requests that cannot be authenticated as
  # actual Twilio requests should not make it to this controller action.
  def show
    xml = Telephony::Twilio::ProgrammableVoiceMessage.from_callback(request.original_url).twiml
    render xml: xml
  rescue Telephony::Twilio::ProgrammableVoiceMessage::CallbackUrlError => err
    NewRelic::Agent.notice_error(err)
    render xml: '', status: :bad_request
  end
end
