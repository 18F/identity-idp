require 'rails_helper'

describe FriendlyError::Message do
  context 'when a known error occures with a friendly translation' do
    FRIENDLY_ERROR_CONFIG.each do |parent|
      path = parent.first
      FRIENDLY_ERROR_CONFIG[path].each do |key, error|
        it "returns friendly_errors.#{path}.#{key} I18n value when error is '#{error}'" do
          message = FriendlyError::Message.call(error, path)
          expect(message).to eq(I18n.t("friendly_errors.#{path}.#{key}"))
        end
      end
    end
  end
end