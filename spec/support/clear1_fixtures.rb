require 'rails_helper'

module Clear1Fixtures
  class << self
    def pass_json
      raw = read_fixture_file_at_path('pass.json')
      JSON.parse(raw).to_json
    end

    def fail_json
      raw = read_fixture_file_at_path('fail.json')
      JSON.parse(raw).to_json
    end

    private

    def read_fixture_file_at_path(filepath)
      expanded_path = Rails.root.join(
        'spec',
        'fixtures',
        'proofing',
        'clear1',
        filepath,
      )
      File.read(expanded_path)
    end
  end
end
