# frozen_string_literal: true

module DocAuth
  module Mock
    module YmlLoaderConcern
      extend ActiveSupport::Concern
      # @param [String] uploaded_file: string content
      def parse_yaml(uploaded_file)
        data = YAML.safe_load(uploaded_file, permitted_classes: [Date])
        if data.is_a?(Hash)
          ['dob', 'state_id_expiration'].each do |dt|
            if (m = data.dig('document', dt).to_s.
              match(%r{(?<month>\d{1,2})/(?<day>\d{1,2})/(?<year>\d{4})}))
              data['document'][dt] =
                Date.new(m[:year].to_i, m[:month].to_i, m[:day].to_i)
            end
          end

          if data.dig('document', 'zipcode')
            data['document']['zipcode'] = data.dig('document', 'zipcode').to_s
          end

          JSON.parse(data.to_json) # converts Dates back to strings
        else
          { general: ["YAML data should have been a hash, got #{data.class}"] }
        end
      rescue Psych::SyntaxError
        if uploaded_file.ascii_only? # don't want this error for images
          { general: ['invalid YAML file'] }
        else
          {}
        end
      end
    end
  end
end
