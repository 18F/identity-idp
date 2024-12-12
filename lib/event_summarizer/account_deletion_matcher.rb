# frozen_string_literal: true

module EventSummarizer
  class AccountDeletionMatcher
    ACCOUNT_DELETION_STARTED_EVENT = 'Account Reset: request'
    ACCOUNT_DELETION_SUBMITTED_EVENT = 'Account Reset: delete'
    ACCOUNT_DELETION_CANCELED_EVENT = 'Account Reset: cancel'

    EVENT_PROPERTIES = ['@message', 'properties', 'event_properties'].freeze

    attr_accessor :account_deletion_events, :event_summaries

    def initialize
      @account_deletion_events = Array.new
      @event_summaries = Array.new
      account_deletion_events
    end

    def handle_cloudwatch_event(event)
      case event['name']
      when ACCOUNT_DELETION_STARTED_EVENT
        process_account_reset_request(event)
      when ACCOUNT_DELETION_SUBMITTED_EVENT
        process_account_reset_delete(event)
      when ACCOUNT_DELETION_CANCELED_EVENT
        process_account_reset_cancel(event)
      end
    end

    def finish
      event_summaries
    end

    private

    def process_account_reset_request(event)
      event_message = {
        title: 'Account deletion Request',
        attributes: [
          { type: :account_deletion_request,
            description: "On #{event["@timestamp"]} user initiated account deletion" },
        ],
      }
      event_summaries.push(event_message)
    end

    def process_account_reset_cancel(event)
      event_message = {
        title: 'Account deletion cancelled',
        attributes: [
          { type: :account_deletion_cancelled,
            description: "On #{event["@timestamp"]} user initiated account deletion" },
        ],
      }
      event_summaries.push(event_message)
    end

    def process_account_reset_delete(event)
      message = event['@message']
      age = message['properties']['event_properties']['account_age_in_days']
      date = event['@timestamp']
      event_message = {
        title: 'Account deleted',
        attributes: [
          {
            type: :account_deleted,
            description: "On #{date} user deleted their account which was #{age} days old",
          },
        ],
      }
      event_summaries.push(event_message)
    end
  end
end
