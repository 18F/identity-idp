module Idv
  module InheritedProofing
    module Va
      class Form
        include ActiveModel::Model

        class << self
          def model_name
            ActiveModel::Name.new(self, nil, namespaced_model_name)
          end

          def namespaced_model_name
            self.to_s.gsub('::', '')
          end

          # Returns the field names based on the validators we've set up.
          def field_names
            @field_names ||= validators.filter_map do |validator|
              validator.attributes.first
            end&.flatten&.uniq&.sort
          end
        end

        private_class_method :namespaced_model_name

        attr_reader :payload_hash

        validate :validate_field_names

        validates :first_name, presence: true, length: { maximum: 255 }
        validates :last_name, presence: true, length: { maximum: 255 }
        validates :phone, length: { maximum: 11 }
        validates :birth_date, presence: true
        validates :ssn, presence: true
        validates :address_street, presence: true, length: { maximum: 255 }
        validates :address_street2, length: { maximum: 255 }
        validates :address_city, length: { maximum: 255 }
        validates :address_state, length: { maximum: 2 }
        validates :address_country, length: { maximum: 255 }
        validates :address_zip, presence: true
        validates_format_of :address_zip, with: /\A\d{5}(-?\d{4})?\z/,
                                          message: I18n.t('idv.errors.pattern_mismatch.zipcode'),
                                          allow_blank: false

        # This must be performed after our validators are defined.
        attr_accessor(*self.field_names)

        def initialize(payload_hash:)
          raise ArgumentError, 'payload_hash is blank?' if payload_hash.blank?
          raise ArgumentError, 'payload_hash is not a Hash' unless payload_hash.is_a? Hash

          @payload_hash = payload_hash.dup

          populate_field_data
        end

        def submit
          validate

          FormResponse.new(
            success: valid?,
            errors: errors,
            extra: {
            },
          )
        end

        private

        attr_writer :payload_hash

        # Populates our field data from the payload hash.
        def populate_field_data
          payload_field_info.each do |field_name, field_info|
            value = payload_hash.dig(
              *[field_info[:namespace],
                field_info[:field_name]].flatten.compact,
            )
            public_send("#{field_name}=", value)
          end
        end

        # Validator for field names. All fields (not the presence of data) are required.
        def validate_field_names
          self.class.field_names.each do |field_name|
            next if payload_field_info.key? field_name
            errors.add(field_name, 'field is missing', type: missing_required_field)
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
end
