require 'rails_helper'

RSpec.describe Idv::IdentityResolver do
  let(:pii_from_doc) { {} }
  let(:pii_from_user) { {} }

  it 'calls all plugins' do
    plugin_a = double
    expect(plugin_a).to receive(:resolve_identity) do |
        pii_from_doc:,
        pii_from_user:,
        result:,
        next_plugin:
    |
      next_plugin.call
    end

    plugin_b = double
    expect(plugin_b).to receive(:resolve_identity)

    resolver = described_class.new(
      plugins: [
        plugin_a,
        plugin_b,
      ],
    )

    resolver.resolve_identity(
      pii_from_doc:,
      pii_from_user:,
    )
  end

  it 'allows plugins to stop the chain' do
    plugin_a = double
    expect(plugin_a).to receive(:resolve_identity) do |
        pii_from_doc:,
        pii_from_user:,
        result:, next_plugin:
    |
      result.merge(
        result_from_plugin_a: true,
      )
    end

    plugin_b = double
    expect(plugin_b).not_to receive(:resolve_identity)

    resolver = described_class.new(
      plugins: [plugin_a, plugin_b],
    )

    result = resolver.resolve_identity(pii_from_doc:, pii_from_user:)

    expect(result).to eql(
      {
        result_from_plugin_a: true,
      },
    )
  end
end
