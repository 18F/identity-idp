require 'rails_helper'
RSpec.describe AttemptsApi::TrackerEvents do
  # To run these specs locally, you need to compile the OpenAPI spec.
  # Either run `npm run build:openapi` in the root of the project or uncomment out the below lines.
  # after(:all) do
  #   FileUtils.rm('./docs/attempts-api/compiled-api.yml')
  # end

  # result = system('npm run build:openapi')
  # raise 'Failed to compile OpenAPI spec' unless result

  @event_data = begin
    begin
      spec = Openapi3Parser.load(File.open('./docs/attempts-api/compiled-api.yml'))
    rescue Errno::ENOENT
      raise 'Compiled OpenAPI spec not found. Please run `npm run build:openapi` before running these tests.'
    end
    spec.components.schemas.each_with_object({}) do |(name, values), hash|
      next unless values['allOf']
      next if name.include?('Event')
      props = values['allOf'][1]&.properties&.keys&.map(&:to_sym)
      hash[name] = props || []
    end
  end

  let(:methods) do
    AttemptsApi::TrackerEvents.instance_methods
  end

  @event_data.each do |name, props|
    it "defines a method for #{name} with the correct properties" do
      expect(methods).to include(name.underscore.to_sym)

      method = AttemptsApi::TrackerEvents.instance_method(name.underscore.to_sym)

      # Remove :user_id from the method parameters as it is not part of the API
      method_props = method.parameters.map(&:last).reject { |param| param == :user_id }
      expect(method_props).to match_array(props)
    end
  end
end
