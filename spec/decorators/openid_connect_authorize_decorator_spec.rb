require 'rails_helper'

RSpec.describe OpenidConnectAuthorizeDecorator do
  subject(:decorator) do
    OpenidConnectAuthorizeDecorator.new(scopes: scopes)
  end

  let(:scopes) { %w[openid email profile] }

  describe '#requested_attributes' do
    it 'is the openid claims for the scopes requested' do
      expect(decorator.requested_attributes).
        to match_array(%w[email given_name family_name birthdate])
    end
  end
end
