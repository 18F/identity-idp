require 'rails_helper'

RSpec.describe Idv::IdentityResolver do
  let(:input) { {} }

  it 'calls all plugins' do
    plugin_a = double
    expect(plugin_a).to receive(:resolve_identity) do |input:, result:, next_plugin:|
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

    resolver.resolve_identity(input:)
  end

  it 'allows plugins to stop the chain' do
    plugin_a = double
    expect(plugin_a).to receive(:resolve_identity) do |input:, result:, next_plugin:|
      result.merge(
        result_from_plugin_a: true,
      )
    end

    plugin_b = double
    expect(plugin_b).not_to receive(:resolve_identity)

    resolver = described_class.new(
      plugins: [plugin_a, plugin_b],
    )

    result = resolver.resolve_identity(input:)

    expect(result).to eql(
      {
        result_from_plugin_a: true,
      },
    )
  end

  it 'allows merging values into the result' do
    plugin_a = double
    expect(plugin_a).to receive(:resolve_identity) do |next_plugin:, **kwargs|
      next_plugin.call plugin_a: 'foo'
    end

    plugin_b = double
    expect(plugin_b).to receive(:resolve_identity) do |next_plugin:, **kwargs|
      next_plugin.call plugin_b: 'bar'
    end

    resolver = described_class.new(
      plugins: [
        plugin_a,
        plugin_b,
      ],
    )

    result = resolver.resolve_identity(input:)

    expect(result).to eql(
      {
        plugin_a: 'foo',
        plugin_b: 'bar',
      },
    )
  end

  it 'raises if you try to overwrite and merge into result' do
    plugin = double
    expect(plugin).to receive(:resolve_identity) do |next_plugin:, **kwargs|
      next_plugin.call result: { foo: true }, bar: true
    end

    resolver = described_class.new(plugins: [plugin])

    expect do
      resolver.resolve_identity(input:)
    end.to raise_error "Can't specify result: and additional arguments"
  end
end
