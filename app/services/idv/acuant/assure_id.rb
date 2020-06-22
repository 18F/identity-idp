module Idv
  module Acuant
    class AssureId
      include Idv::Acuant::Http

      base_uri Figaro.env.acuant_assure_id_url

      BACK = 1

      attr_accessor :instance_id

      def initialize(cfg = default_cfg)
        @subscription_id = cfg.fetch(:subscription_id)
        @authentication_params = cfg.slice(:username, :password)
        @instance_id = nil
      end

      def post_back_image(image)
        post_image(image, BACK)
      end

      def results
        url = "/AssureIDService/Document/#{instance_id}"

        options = default_options.merge(
          headers: accept_json,
        )

        get(url, options, &JSON.method(:parse))
      end

      def face_image
        url = "/AssureIDService/Document/#{instance_id}/Field/Image?key=Photo"

        get(url, default_options)
      end

      def post_image(image, side)
        url = "/AssureIDService/Document/#{instance_id}/Image?side=#{side}&light=0"

        options = default_options.merge(
          headers: accept_json,
          body: image,
        )

        post(url, options)
      end

      def document
        options = default_options.merge(
          headers: content_type_json.merge(accept_json),
        )

        url = "/AssureIDService/Document/#{instance_id}"
        get(url, options)
      end

      private

      def image_params
        {
          AuthenticationSensitivity: 0, # normal
          ClassificationMode: 0, # automatic
          Device: device_params,
          ImageCroppingExpectedSize: '1', # id
          ImageCroppingMode: '1', # automatic
          ManualDocumentType: nil,
          ProcessMode: 0, # default
          SubscriptionId: @subscription_id,
        }.to_json
      end

      def device_params
        {
          HasContactlessChipReader: false,
          HasMagneticStripeReader: false,
          SerialNumber: 'xxx',
          Type: {
            Manufacturer: 'Login.gov',
            Model: 'Doc Auth 1.0',
            SensorType: '3', # mobile
          },
        }
      end

      def default_cfg
        {
          subscription_id: env.acuant_assure_id_subscription_id,
          username: env.acuant_assure_id_username,
          password: env.acuant_assure_id_password,
        }
      end

      def default_options
        { basic_auth: @authentication_params }
      end
    end
  end
end
