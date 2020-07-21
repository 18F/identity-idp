# Controller to receive SET (Security Event Tokens)
class SecurityEventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    form = SecurityEventForm.new(body: request.body)
    response = form.submit

    if response.success?
      head :accepted
    else
      render json: {
        err: form.err,
        description: form.description,
      }
    end
  end
end
