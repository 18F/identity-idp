module Idv
  module Acuant
    class AssureId
      include Idv::Acuant::Http

      base_uri Figaro.env.acuant_assure_id_url

      attr_accessor :instance_id

      def initialize(cfg = default_cfg)
        @subscription_id = cfg.fetch(:subscription_id)
        @authentication_params = cfg.slice(:username, :password)
        @instance_id = nil
      end

      def face_image
        url = "/AssureIDService/Document/#{instance_id}/Field/Image?key=Photo"

        get(url, default_options)
      end

      private

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
