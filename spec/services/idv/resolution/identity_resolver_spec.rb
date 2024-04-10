require 'rails_helper'

RSpec.describe Idv::Resolution::IdentityResolver do
  let(:input) { {} }

  it 'calls all plugins' do
    plugin_a = double
    expect(plugin_a).to receive(:call) do |input:, result:, next_plugin:|
      next_plugin.call
    end

    plugin_b = double
    expect(plugin_b).to receive(:call)

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
    expect(plugin_a).to receive(:call) do |result:, **|
      result.merge(
        result_from_plugin_a: true,
      )
    end

    plugin_b = double
    expect(plugin_b).not_to receive(:call)

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

  it 'allows altering input' do
    plugin_a = double
    expect(plugin_a).to receive(:call) do |input:, next_plugin:, **|
      next_plugin.call(
        input: input.with(
          state_id: input.state_id.with(
            first_name: 'CHANGED',
          ),
        ),
      )
    end

    plugin_b = double
    expect(plugin_b).to receive(:call) do |input:, **|
      expect(input.state_id.first_name).to eql('CHANGED')
    end

    resolver = described_class.new(
      plugins: [plugin_a, plugin_b],
    )

    input = Idv::Resolution::Input.new(
      state_id: {
        first_name: 'original',
      },
    )

    resolver.resolve_identity(input:)
  end

  it 'allows merging values into the result' do
    plugin_a = double
    expect(plugin_a).to receive(:call) do |next_plugin:, **|
      next_plugin.call plugin_a: 'foo'
    end

    plugin_b = double
    expect(plugin_b).to receive(:call) do |next_plugin:, **|
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

  it 'allows overriding the result' do
    plugin_a = double
    expect(plugin_a).to receive(:call) do |next_plugin:, **|
      next_plugin.call plugin_a: 'foo'
    end

    plugin_b = double
    expect(plugin_b).to receive(:call) do |next_plugin:, **|
      next_plugin.call result: { plugin_b: 'bar' }
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
        plugin_b: 'bar',
      },
    )
  end

  it 'raises if you try to overwrite and merge into result' do
    plugin = double
    expect(plugin).to receive(:call) do |next_plugin:, **|
      next_plugin.call result: { foo: true }, bar: true
    end

    resolver = described_class.new(plugins: [plugin])

    expect do
      resolver.resolve_identity(input:)
    end.to raise_error "Can't specify result: and additional arguments"
  end
end
