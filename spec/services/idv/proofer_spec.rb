require 'rails_helper'

describe Idv::Proofer do
  describe '.attribute?' do
    subject { described_class.attribute?(attribute) }

    context 'when the attribute exists' do
      context 'and is passed as a string' do
        let(:attribute) { 'last_name' }

        it { is_expected.to eq(true) }
      end

      context 'and is passed as a symbol' do
        let(:attribute) { :last_name }

        it { is_expected.to eq(true) }
      end
    end

    context 'when the attribute does not exist' do
      context 'and is passed as a string' do
        let(:attribute) { 'fooobar' }

        it { is_expected.to eq(false) }
      end

      context 'and is passed as a symbol' do
        let(:attribute) { :fooobar }

        it { is_expected.to eq(false) }
      end
    end
  end

  describe '.loaded_vendors' do
    subject { described_class.send(:loaded_vendors) }

    it 'returns all of the subclasses of Proofer::Base' do
      subclasses = ['foo']
      expect(::Proofer::Base).to receive(:descendants).and_return(subclasses)
      expect(subject).to eq(subclasses)
    end
  end

  describe '.available_vendors' do
    subject { described_class.send(:available_vendors, configured_vendors, vendors) }

    let(:vendors) do
      [
        class_double('Proofer::Base', vendor_name: 'foo'),
        class_double('Proofer::Base', vendor_name: 'baz'),
      ]
    end

    let(:configured_vendors) { %w[foo bar] }

    it 'selects only the vendors that have been configured' do
      available_vendors = [vendors.first]
      expect(subject).to eq(available_vendors)
    end
  end

  describe '.require_mock_vendors' do
    subject { described_class.send(:require_mock_vendors) }

    it 'requires all of the mock vendors' do
      Dir[Rails.root.join('lib', 'proofer_mocks', '*')].each do |file|
        expect_any_instance_of(Object).to receive(:require).with(file)
      end

      subject
    end
  end

  describe '.assign_vendors' do
    subject { described_class.send(:assign_vendors, stages, external_vendors, mock_vendors) }

    let(:stages) { %i[resolution state_id address] }

    let(:external_vendors) do
      [
        class_double('Proofer::Base', stage: :resolution),
        class_double('Proofer::Base', stage: :foo),
      ]
    end

    let(:mock_vendors) do
      [
        class_double('Proofer::Base', stage: :resolution),
        class_double('Proofer::Base', stage: 'state_id'),
        class_double('Proofer::Base', stage: :baz),
      ]
    end

    it 'maps stages to vendors, falling back to mock vendors' do
      assigned_vendors = {
        resolution: external_vendors.first,
        state_id: mock_vendors.second,
      }
      expect(subject).to eq(assigned_vendors)
    end
  end

  describe '.stage_vendor' do
    subject { described_class.send(:stage_vendor, stage, vendors) }

    let(:stage) { :foo }

    context 'when stage is a string' do
      let(:vendors) do
        [
          class_double('Proofer::Base', stage: :resolution),
          class_double('Proofer::Base', stage: 'foo'),
        ]
      end

      it 'selects the vendor for the stage' do
        expect(subject).to eq(vendors.second)
      end
    end

    context 'when stage is a symbol' do
      let(:vendors) do
        [
          class_double('Proofer::Base', stage: :resolution),
          class_double('Proofer::Base', stage: :foo),
        ]
      end

      it 'selects the vendor for the stage' do
        expect(subject).to eq(vendors.second)
      end
    end

    context 'when no vendor exists' do
      let(:vendors) do
        [
          class_double('Proofer::Base', stage: :resolution),
        ]
      end

      it 'is nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '.validate_vendors' do
    subject { described_class.send(:validate_vendors, stages, vendors) }

    let(:stages) { %i[foo] }

    context 'when there are vendors for all stages' do
      let(:vendors) { { foo: class_double('Proofer::Base') } }

      it 'does not raise an error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when there are stages without vendors' do
      let(:vendors) { { bar: class_double('Proofer::Base') } }

      it 'does raises an error' do
        expect { subject }.to raise_error("No proofer vendor configured for stage(s): foo")
      end
    end
  end

  describe '.configure_vendors' do
    subject { described_class.configure_vendors(stages, config) }

    let(:stages) { %i[foo] }

    let(:config) { double }

    let(:configured_vendors) { %w[vendor1 vendor2] }

    let(:loaded_vendors) do
      [
        class_double('Proofer::Base', stage: :foo, vendor_name: 'vendor3'),
        class_double('Proofer::Base', stage: :foo, vendor_name: 'vendor1'),
        class_double('Proofer::Base', stage: :bar, vendor_name: 'vendor2'),
      ]
    end

    let(:mock_vendors) do
      [
        class_double('Proofer::Base', stage: :foo),
        class_double('Proofer::Base', stage: :baz),
      ]
    end

    before do
      expect(config).to receive(:vendors).and_return(configured_vendors)
    end

    context 'default configuration' do
      before do
        expect(config).to receive(:mock_fallback).and_return(false)
        expect(config).to receive(:raise_on_missing_proofers).and_return(true)
        expect(described_class).to receive(:loaded_vendors).and_return(loaded_vendors, loaded_vendors)
      end

      context 'when a stage is missing an external vendor' do
        let(:stages) { %i[foo baz] }

        it 'raises' do
          expect { subject }.to raise_error("No proofer vendor configured for stage(s): baz")
        end
      end

      context 'when all stages have vendors' do
        it 'maps the vendors, ignoring non-configured ones' do
          expect(subject).to eq({ foo: loaded_vendors.second })
        end
      end
    end

    context 'when mock_fallback is enabled' do
      before do
        expect(config).to receive(:mock_fallback).and_return(true)
        expect(config).to receive(:raise_on_missing_proofers).and_return(true)
        expect(described_class).to receive(:loaded_vendors).and_return(loaded_vendors, mock_vendors)
      end

      context 'when a stage is missing an external vendor' do
        let(:stages) { %i[foo baz] }

        it 'does not raise' do
          expect { subject }.not_to raise_error
        end

        it 'returns the mapped vendors with the mock fallback' do
          expect(subject).to eq(foo: loaded_vendors.second, baz: mock_vendors.second)
        end
      end
    end

    context 'when raise_on_missing_proofers is disabled' do
      before do
        expect(config).to receive(:mock_fallback).and_return(false)
        expect(config).to receive(:raise_on_missing_proofers).and_return(false)
        expect(described_class).to receive(:loaded_vendors).and_return(loaded_vendors, loaded_vendors)
      end

      context 'when a stage is missing an external vendor' do
        let(:stages) { %i[foo baz] }

        it 'does not raise' do
          expect { subject }.not_to raise_error
        end

        it 'returns the mapped vendors missing the stage' do
          expect(subject).to eq(foo: loaded_vendors.second)
        end
      end
    end
  end
end
