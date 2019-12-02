require 'rails_helper'

describe FriendlyError::FindKey do
  context 'for each config item in config/friendly_error/config.yml' do
    FRIENDLY_ERROR_CONFIG.each do |parent|
      path = parent.first
      FRIENDLY_ERROR_CONFIG[path].each do |key, error|
        it "returns the #{key} for error '#{error}'" do
          error_key = FriendlyError::FindKey.call(error, path)
          expect(error_key).to eq(key)
        end
      end
    end
  end
end