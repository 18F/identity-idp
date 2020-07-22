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
      @client = DocAuthClient.client
      create_document_response = @client.create_document
      if create_document_response.success?
        @instance_id = create_document_response.instance_id
        upload_and_check_images
      else
        error_json create_document_response.errors.first
      end
    end

    def upload_and_check_images
      image_mappings = {
        post_front_image: @front_image,
        post_back_image: @back_image,
      }
      if FeatureManagement.liveness_checking_enabled?
        image_mappings[:post_selfie] = @selfie_image
      end
      image_mappings.each do |method_name, image|
        error_response = post_image_step(method_name, image)
        return error_response if error_response
      end
      {
        status: 'success',
        message: 'Uploaded images',
      }
    end

    def post_image_step(image_step, image)
      post_response = @client.send(image_step,
                                   image: image,
                                   instance_id: @instance_id)
      error_json(post_response.errors.first) unless post_response.success?
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
