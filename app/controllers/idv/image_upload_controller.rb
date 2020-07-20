module Idv
  class ImageUploadController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated


    def upload
      validation_error = validate_request(request)
      response = validation_error || handle_images
      render json: response
    end

    private

    def handle_images
      puts("Got images")
      {
        status: 'success',
        message: 'hello'
      }
    end

    def validate_request(request)
      steps = %i[check_content_type check_image_fields]
      steps.each do |step|
        err = method(step).call(request)
        return error_json(err) if err
      end
    end

    def check_content_type(request)
      "Invalid content type #{request.content_type}" if request.content_type != 'application/json'
    end

    def check_image_fields
      @front_image = request.body['front']
      @back_image = request.body['back']
      @selfie_image = request.body['selfie']
      'Missing image keys' unless [@front_image, @back_image, @selfie_image].all?
    end

    def error_json(reason)
      JSON.dump(
        status: 'error',
        message: reason,
      )
    end

  end
end
