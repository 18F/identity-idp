require 'rails_helper'

RSpec.describe IdentityConfig do
  describe '.key_types' do
    it 'has all _enabled keys as booleans' do
      aggregate_failures do
        IdentityConfig.key_types.select { |key, _type| key =~ /_enabled$/ }.
          each do |key, type|
            expect(type).to eq(:boolean), "expected #{key} to be a boolean"
          end
      end
    end

    it 'has all _at keys as timestamps' do
      aggregate_failures do
        IdentityConfig.key_types.select { |key, _type| key =~ /_at$/ }.
          each do |key, type|
            expect(type).to eq(:timestamp), "expected #{key} to be a timestamp"
          end
      end
    end
  end
end
