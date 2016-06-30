require 'rails_helper'

TESTS = ['demo'].freeze

describe 'YAML config for A/B testing' do
  it 'includes the expected tests' do
    config = YAML.load_file("#{Rails.root}/config/experiments.yml")

    expect(config.keys).to eq TESTS
  end
end
