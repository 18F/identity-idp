module Api
  class DocumentCaptureForm
    def initialize(front_image_iv:,
                   back_image_iv:,
                   selfie_image_iv:,
                   front_image_url:,
                   back_image_url:,
                   selfie_image_url:)
      @encryption_key = password
      @jwt = jwt
      @front_image_iv = front_image_iv
      @back_image_iv = back_image_iv
      @selfie_image_iv = selfie_image_iv
      @front_image_url = front_image_url
      @back_image_url = back_image_url
      @selfie_image_url = selfie_image_url
    end

    private

    def form_submit
      response = form.submit
      presenter = ImageUploadResponsePresenter.new(
        form_response: response,
        url_options: url_options,
      )
      status = :accepted if response.success?
      render_json(
        presenter,
        status: status || presenter.status,
      )
      response
    end

    def image_params
      params.permit(
        ['encryption_key', 'front_image_iv', 'back_image_iv', 'selfie_image_iv',
         'front_image_url', 'back_image_url', 'selfie_image_url'],
      )
    end

    def image_metadata
      params.permit(:front_image_metadata, :back_image_metadata).
        to_h.
        transform_values do |str|
        JSON.parse(str)
      rescue JSON::ParserError
        nil
      end.
        compact.
        transform_keys { |key| key.gsub(/_image_metadata$/, '') }.
        deep_symbolize_keys
    end
  end
end
