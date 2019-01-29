require 'rails_helper'

describe Idv::Proofer do
  let(:resolution_dummy) do
    class_double('Proofer::Base', vendor_name: 'dummy:resolution', stage: :resolution)
  end
  let(:state_id_dummy) do
    class_double('Proofer::Base', vendor_name: 'dummy:state_id', stage: :state_id)
  end
  let(:address_dummy) do
    class_double('Proofer::Base', vendor_name: 'dummy:address', stage: :address)
  end
  let(:dummy_vendors) { [resolution_dummy, state_id_dummy, address_dummy] }

  let(:proofer_vendors) { '["dummy:resolution", "dummy:state_id", "dummy:address"]' }
  let(:proofer_mock_fallback) { 'false' }

  before do
    allow(Figaro.env).to receive(:proofer_vendors).
      and_return(proofer_vendors)
    allow(Figaro.env).to receive(:proofer_mock_fallback).
      and_return(proofer_mock_fallback)

    original_descendants = Proofer::Base.descendants
    allow(Proofer::Base).to receive(:descendants).and_return(
      original_descendants + dummy_vendors,
    )

    subject.instance_variable_set(:@vendors, nil)
  end

  after do
    # This is necessary to prevent mocks created in these examples from leaking
    # out with the memoized vendors value
    subject.instance_variable_set(:@vendors, nil)
  end

  subject { described_class }

  describe '.attribute?' do
    context 'when the attribute exists' do
      context 'and is passed as a string' do
        let(:attribute) { 'last_name' }

        it { expect(subject.attribute?(attribute)).to eq(true) }
      end

      context 'and is passed as a symbol' do
        let(:attribute) { :last_name }

        it { expect(subject.attribute?(attribute)).to eq(true) }
      end
    end

    context 'when the attribute does not exist' do
      context 'and is passed as a string' do
        let(:attribute) { 'fooobar' }

        it { expect(subject.attribute?(attribute)).to eq(false) }
      end

      context 'and is passed as a symbol' do
        let(:attribute) { :fooobar }

        it { expect(subject.attribute?(attribute)).to eq(false) }
      end
    end
  end

  describe '.get_vendor' do
    context 'with mock proofers enabled' do
      let(:proofer_mock_fallback) { 'true' }

      context 'with a vendor configured for the state' do
        it 'returns the vendor' do
          expect(subject.get_vendor(:resolution)).to eq(resolution_dummy)
          expect(subject.get_vendor(:state_id)).to eq(state_id_dummy)
          expect(subject.get_vendor(:address)).to eq(address_dummy)
        end
      end

      context 'without a vendor configured for the state' do
        let(:proofer_vendors) { '["dummy:state_id"]' }

        it 'returns a mock vendor' do
          expect(subject.get_vendor(:resolution)).to eq(ResolutionMock)
          expect(subject.get_vendor(:state_id)).to eq(state_id_dummy)
          expect(subject.get_vendor(:address)).to eq(AddressMock)
        end
      end

      context 'without a proofer vendor configuration' do
        let(:proofer_vendors) { nil }

        it 'returns all mock proofers' do
          expect(subject.get_vendor(:resolution)).to eq(ResolutionMock)
          expect(subject.get_vendor(:state_id)).to eq(StateIdMock)
          expect(subject.get_vendor(:address)).to eq(AddressMock)
        end
      end
    end

    context 'without mock proofers enabled' do
      let(:proofer_mock_fallback) { 'false' }

      context 'with a vendor configured for the state' do
        it 'returns the vendor' do
          expect(subject.get_vendor(:resolution)).to eq(resolution_dummy)
          expect(subject.get_vendor(:state_id)).to eq(state_id_dummy)
          expect(subject.get_vendor(:address)).to eq(address_dummy)
        end
      end

      context 'without a vendor configured for the state' do
        let(:proofer_vendors) { '["dummy:state_id"]' }

        it 'returns nil' do
          expect(subject.get_vendor(:resolution)).to eq(nil)
          expect(subject.get_vendor(:state_id)).to eq(state_id_dummy)
          expect(subject.get_vendor(:address)).to eq(nil)
        end
      end

      context 'without a proofer vendor configuration' do
        let(:proofer_vendors) { nil }

        it 'returns nil' do
          expect(subject.get_vendor(:resolution)).to eq(nil)
          expect(subject.get_vendor(:state_id)).to eq(nil)
          expect(subject.get_vendor(:address)).to eq(nil)
        end
      end
    end
  end

  describe '.validate_vendors!' do
    let(:proofer_mock_fallback) { 'false' }

    context 'with vendors configured for each stage' do
      it 'does not raise' do
        expect { described_class.validate_vendors! }.to_not raise_error
      end
    end

    context 'without vendors configured for each stage' do
      let(:proofer_vendors) { '["dummy:state_id"]' }

      it 'does raise' do
        expect { described_class.validate_vendors! }.to raise_error(
          RuntimeError, 'No proofer vendor configured for stage(s): resolution, address'
        )
      end
    end

    context 'without vendors configured but with mock vendors enabled' do
      let(:proofer_vendors) { '["dummy:state_id"]' }
      let(:proofer_mock_fallback) { 'true' }

      it 'does not raise' do
        expect { described_class.validate_vendors! }.to_not raise_error
      end
    end
  end
end
