# frozen_string_literal: true

module EventSummarizer
    class PasswordResetMatcher
      PASSWORD_RESET_REQUESTED_EVENT = 'Password Reset: Email Submitted'
      PASSWORD_RESET_COMPLETED_EVENT = 'Password Reset: Password Submitted'
  
      EVENT_PROPERTIES = ['@message', 'properties', 'event_properties'].freeze
  
      attr_accessor :event_summaries
  
      def initialize
        @event_summaries = Array.new
      end
  
      def handle_cloudwatch_event(event)
        case event['name']
        when PASSWORD_RESET_REQUESTED_EVENT
          process_password_reset_request(event)
        when PASSWORD_RESET_COMPLETED_EVENT
          process_password_reset_submitted(event)
        end
      end
  
      def finish
        event_summaries
      end
  
      private
  
      def process_password_reset_request(event)
        puts event
        event_message = {
          title: 'Account deletion Request',
          attributes: [
            { 
              type: :account_deletion_request, 
            }
          ],
        }
        event_summaries.push(event_message)
      end
  
      def process_password_reset_submitted(event)
        message = event['@message']
        pust event
        date = event['@timestamp']
        event_message = {
          title: 'Account deletion Request',
          attributes: [
            {
              type: :account_deletion_request,
            },
          ],
        }
        event_summaries.push(event_message)
      end
    end
  end
  