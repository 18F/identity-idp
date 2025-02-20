# frozen_string_literal: true

module Test
  class FakeSocureController < ApplicationController
    skip_before_action :verify_authenticity_token

    def index
      fixture_file_dir = Rails.root.join('spec', 'fixtures', 'socure_docv')
      Rails.logger.debug { "fixture_file_dir: #{fixture_file_dir.inspect}" }

      fixture_files = Dir["#{fixture_file_dir}/*.json"]
      Rails.logger.debug { "fixture_files: #{fixture_files.inspect}" }

      @socure_fixtures = fixture_files.map do |fixture_file|
        [
          File.basename(fixture_file),
          JSON.parse(File.read(fixture_file), symbolize_keys: true),
        ]
      end.to_h

      config_json = params[:fake_socure_configuration]
      config_hash = config_json ? JSON.parse(config_json, symbolize_keys: true) : {}
      @socure_configuration = Test::FakeSocureConfig.new(**config_hash)
    end
  end
end
