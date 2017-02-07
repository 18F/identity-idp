require 'rails_helper'

RSpec.describe ServiceProviderSessionDecorator do
  it 'has the same public API as SessionDecorator' do
    SessionDecorator.public_instance_methods.each do |method|
      expect(
        described_class.public_method_defined?(method)
      ).to be(true), "expected #{described_class} to have ##{method}"
    end
  end

  describe '#logo_partial' do
    context 'logo present' do
      it 'returns branded logo partial' do
        decorator = ServiceProviderSessionDecorator.new(sp_name: 'Test', sp_logo: 'logo')

        expect(decorator.logo_partial).to eq 'shared/nav_branded_logo'
      end
    end

    context 'logo not present' do
      it 'is null' do
        decorator = ServiceProviderSessionDecorator.new(sp_name: 'Test', sp_logo: nil)

        expect(decorator.logo_partial).to eq 'shared/null'
      end
    end
  end
end
