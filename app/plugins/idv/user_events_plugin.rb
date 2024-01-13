# Plugin responsible for logging UserEvent instances in response to actions
# in the IDP.
module Idv
  class UserEventsPlugin < BasePlugin
    on_step_completed :request_letter do |request:, user:, **rest|
      UserEventCreator.new(request: request, current_user: user).create_user_event(type, user)
    end
  end
end
