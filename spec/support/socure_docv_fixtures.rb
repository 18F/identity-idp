require 'rails_helper'

module SocureDocvFixtures
  class << self
    def pass_json
      raw = read_fixture_file_at_path('pass.json')
      JSON.parse(raw).to_json
    end

    def fail_json(errors)
      raw = read_fixture_file_at_path('pass.json')
      body = JSON.parse(raw)

      body['documentVerification']['decision']['value'] = 'reject'
      body['documentVerification']['reasonCodes'] = errors

      body.to_json
    end

    private

    def read_fixture_file_at_path(filepath)
      expanded_path = Rails.root.join(
        'spec',
        'fixtures',
        'socure_docv',
        filepath,
      )
      File.read(expanded_path)
    end
  end
end
