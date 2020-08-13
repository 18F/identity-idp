module Idv
  class ImageUploadController < ApplicationController
    include IdvSession

    respond_to :json

    def create
      image_form = ApiImageUploadForm.new(params)
      form_response = image_form.submit



      if form_response.success?
        doc_response = doc_auth_client.post_images(
          front_image: image_form.front_image,
          back_image: image_form.back_image,
          selfie_image: image_form.back_image,
          liveness_checking_enabled: liveness_checking_enabled?
        )

        # TODO: something better here
        # upload_info = {
        #   documents: doc_response.to_h,
        # }
        # store_pii(doc_response)
        # user_session['idv/doc_auth']['api_upload'] = upload_info
        render_form_response(doc_response)
      else
        render_form_response(form_response)
      end
    end

    # def create
    #   validation_error = validate_request(request)
    #   response = validation_error || upload_and_check_images
    #   render json: response
    # end

    private

    def render_form_response(form_response)
      if form_response.success?
        render json: {
          success: true
        }
      else
        render json: form_response.to_h, status: :bad_request
      end
    end

    def upload_and_check_images
      doc_response = client.post_images(front_image: @front_image,
                                        back_image: @back_image,
                                        selfie_image: @selfie_image,
                                        liveness_checking_enabled: liveness_checking_enabled?)
      return error_json(doc_response.errors.first) unless doc_response.success?
    end

    def store_pii(doc_response)
      user_session['idv/doc_auth'][:pii_from_doc] = doc_response.pii_from_doc.merge(
        uuid: current_user.uuid,
        phone: current_user.phone_configurations.take&.phone,
      )
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

    def doc_auth_client
      @doc_auth_client ||= DocAuthClient.client
    end
  end
end
