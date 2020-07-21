module Idv
  class ImageUploadController < ApplicationController
    include IdvSession

    skip_before_action :verify_authenticity_token


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
      nil
    end

    def check_content_type(request)
      "Invalid content type #{request.content_type}" if request.content_type != 'application/json'
    end

    def check_image_fields(request)
      data = request.body.read
      @front_image = data['front']
      @back_image = data['back']
      @selfie_image = data['selfie']
      'Missing image keys' unless [@front_image, @back_image, @selfie_image].all?
    end

    def error_json(reason)
      {
        status: 'error',
        message: reason,
      }
    end

  end
end
