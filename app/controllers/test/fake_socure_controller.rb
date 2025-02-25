# frozen_string_literal: true

module Test
  class FakeSocureController < ApplicationController

    @configurations =
      Dir["#{Rails.root.join('spec', 'fixtures', 'socure_docv')}/*.json"].map do |fixture_file|
      FakeSocureConfig.new(
        name: File.basename(fixture_file),
        body: File.read(fixture_file),
      )
    end

    def self.selected_configuration=(new_value)
      configuration_names = @configurations.map(&:name)
      if new_value.blank?
        @selected_configuration = new_value
        @selected_configuration_body = nil
      elsif configuration_names.include?(new_value)
        @selected_configuration = new_value
        body = @configurations.find do |configuration|
          configuration.name == new_value
        end.body
        @selected_configuration_body = JSON.parse(body)
      end
    end

    class << self
      attr_accessor :configurations, :selected_configuration_body
      attr_reader :selected_configuration
    end

    # TODO: can we not skip this?
    skip_before_action :verify_authenticity_token

    def document_request
      render_json {}
    end

    def docv_results
      { placeholder: 'value' }
    end
  end
end
