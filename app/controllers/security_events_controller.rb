# Controller to receive SET (Security Event Tokens)
class SecurityEventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    response = SecurityEventForm.new(body: request.body)

    head :accepted
  end
end
