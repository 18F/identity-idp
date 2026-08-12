# frozen_string_literal: true

module OutOfBandSessionHelper
  PLACEHOLDER_REQUEST = ActionDispatch::TestRequest.create.freeze

  def write_out_of_band_user_session(session_uuid:, user_session:, expiration: 5.minutes)
    session_store = Rails.application.config.session_store.new(
      {},
      Rails.application.config.session_options,
    )
    session_data = { 'warden.user.user.session' => user_session }

    session_store.send(
      :write_session,
      PLACEHOLDER_REQUEST,
      Rack::Session::SessionId.new(session_uuid),
      session_data,
      expire_after: expiration.to_i,
    )
  end
end

RSpec.configure do |config|
  config.include OutOfBandSessionHelper
end
