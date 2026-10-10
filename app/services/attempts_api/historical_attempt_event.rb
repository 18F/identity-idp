# frozen_string_literal: true

module AttemptsApi
  class HistoricalAttemptEvent < AttemptEvent
    # @param extra_metadata [Hash] members merged into the released event's metadata
    def initialize(event_data:, sp:, extra_metadata: {})
      super(
        jti: event_data['jti'],
        iat: event_data['iat'],
        event_type: event_data['event_type'],
        session_id: event_data['session_id'],
        occurred_at: Time.zone.parse(event_data['occurred_at']),
        event_metadata: transformed_metadata(metadata: event_data['event_metadata'], sp:)
          .merge(extra_metadata.stringify_keys),
      )
    end

    def transformed_metadata(metadata:, sp:)
      user = AgencyIdentity.find_by(uuid: metadata['user_uuid'])&.user
      user_uuid = user.present? ?
        AgencyIdentityLinker.for(user:, service_provider: sp, skip_create: true).uuid :
        nil

      metadata.merge(
        'user_uuid' => user_uuid,
        'application_url' => nil,
        'client_port' => nil,
      )
    end
  end
end
