module Idv
  class ImageUploadController < ApplicationController
    include IdvSession

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
        upload_and_check_images
      else
        error_json create_document_response.errors.first
      end
    end

    def upload_and_check_images
      doc_response = @client.post_images(front_image: @front_image,
                                         back_image: @back_image,
                                         selfie_image: @selfie_image,
                                         liveness_checking_enabled: liveness_checking_enabled?)
      return error_json(doc_response.errors.first) unless doc_response.success?
      upload_info = {
        documents: doc_response,
        instance_id: @instance_id,
        results_response: doc_response,
      }
      user_session['api_upload'] = upload_info
      success_json('Uploaded images')
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

    def success_json(reason)
      {
        status: 'success',
        message: reason,
      }
    end
  end
end
