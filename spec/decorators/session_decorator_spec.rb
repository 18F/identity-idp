require 'rails_helper'

RSpec.describe SessionDecorator do
  it 'has the same public API as ServiceProviderSessionDecorator' do
    ServiceProviderSessionDecorator.public_instance_methods.each do |method|
      expect(described_class.public_method_defined?(method)).to be(true),
        "expected #{described_class} to have ##{method}"
    end
  end
end
