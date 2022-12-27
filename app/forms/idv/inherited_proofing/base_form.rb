module Idv
  module InheritedProofing
    class BaseForm
      include ActiveModel::Model

      class << self
        def model_name
          ActiveModel::Name.new(self, nil, namespaced_model_name)
        end

        def namespaced_model_name
          self.to_s.gsub('::', '')
        end
      end

      private_class_method :namespaced_model_name

      attr_reader :payload_hash

      def initialize(payload_hash:)
        raise ArgumentError, 'payload_hash is blank?' if payload_hash.blank?
        raise ArgumentError, 'payload_hash is not a Hash' unless payload_hash.is_a? Hash

        @payload_hash = payload_hash.dup

        populate_field_data
      end

      def submit
        FormResponse.new(
          success: valid?,
          errors: errors,
          extra: {},
        )
      end

      # Perhaps overkill, but a mapper service of some kind, not bound to this class,
      # that takes into consideration context, may be more suitable. In the meantime,
      # simply return a Hash suitable to place into flow_session[:pii_from_user] in
      # our inherited proofing flow steps.
      def user_pii
        raise NotImplementedError, 'Override this method and return a user PII Hash'
      end

      private

      attr_writer :payload_hash

      # Populates our field data from the payload hash.
      def populate_field_data
        payload_field_info.each do |field_name, field_info|
          # Ignore fields we're not interested in.
          next unless respond_to? field_name

          value = payload_hash.dig(
            *[field_info[:namespace],
              field_info[:field_name]].flatten.compact,
          )
          public_send("#{field_name}=", value)
        end
      end

      def payload_field_info
        @payload_field_info ||= field_name_info_from payload_hash: payload_hash
      end

      # This method simply navigates the payload hash received and creates qualified
      # hash key names that can be used to verify/map to our field names in this model.
      # This can be used to qualify nested hash fields and saves us some headaches
      # if there are nested field names with the same name:
      #
      # given:
      #
      # payload_hash = {
      #   first_name: 'first_name',
      #   ...
      #   address: {
      #     street: '',
      #     ...
      #   }
      # }
      #
      # field_name_info_from(payload_hash: payload_hash) #=>
      #
      # {
      #   :first_name=>{:field_name=>:first_name, :namespace=>[]},
      #   ...
      #   :address_street=>{:field_name=>:street, :namespace=>[:address]},
      #   ...
      # }
      #
      # The generated, qualified field names expected to map to our model, because we named
      # them as such.
      #
      # :field_name is the actual, unqualified field name found in the payload hash sent.
      # :namespace is the hash key by which :field_name can be found in the payload hash
      # if need be.
      def field_name_info_from(payload_hash:, namespace: [], field_name_info: {})
        payload_hash.each do |key, value|
          if value.is_a? Hash
            field_name_info_from payload_hash: value, namespace: namespace << key,
                                 field_name_info: field_name_info
            namespace.pop
            next
          end

          namespace = namespace.dup
          if namespace.blank?
            field_name_info[key] = { field_name: key, namespace: namespace }
          else
            field_name_info["#{namespace.split.join('_')}_#{key}".to_sym] =
              { field_name: key, namespace: namespace }
          end
        end

        field_name_info
      end
    end
  end
end
