require 'rails_helper'

RSpec.describe Idv::Resolution::InstantVerifyPlugin do
  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

  let(:input) do
    Idv::Resolution::Input.from_pii(pii)
  end

  let(:state_id_address_result) do
    Proofing::Resolution::Result.new(success: true)
  end

  let(:address_of_residence_result) do
    Proofing::Resolution::Result.new(success: true)
  end

  let(:prior_address_of_residence_result) { nil }

  let(:prior_state_id_address_result) { nil }

  let(:result) do
    if prior_address_of_residence_result || prior_state_id_address_result
      {
        instant_verify: {
          address_of_residence: prior_address_of_residence_result,
          state_id: prior_state_id_address_result,
        }.compact,
      }
    else
      {}
    end
  end

  let(:proofer) do
    Proofing::Mock::ResolutionMockClient.new.tap do |proofer|
      if input.state_id
        allow(proofer).to receive(:proof).with(
          hash_including(
            **input.state_id.address.to_h,
          ),
        ).and_return(state_id_address_result)
      end

      if input.address_of_residence
        allow(proofer).to receive(:proof).with(
          hash_including(
            **input.address_of_residence.to_h,
          ),
        ).and_return(address_of_residence_result)

      end
    end
  end

  before do
    allow(subject).to receive(:proofer).and_return(proofer)
  end

  describe '#call' do
    context 'when no state_id present' do
      let(:input) do
        Idv::Resolution::Input.from_pii(pii).with(state_id: nil)
      end

      context 'and no address_of_residence present' do
        let(:input) do
          Idv::Resolution::Input.from_pii(pii).with(state_id: nil, address_of_residence: nil)
        end

        it 'returns an empty result' do
          subject.call(
            input:,
            result:,
            next_plugin: next_plugin_expecting(
              instant_verify: {},
            ),
          )
        end

        it 'makes no InstantVerify calls' do
          expect(proofer).not_to receive(:proof)
          subject.call(
            input:,
            result:,
            next_plugin: next_plugin_expecting(anything),
          )
        end
      end

      context 'but address_of_residence present' do
        let(:input) do
          Idv::Resolution::Input.from_pii(pii).with(state_id: nil)
        end

        it 'verifies address_of_residence' do
          expect(proofer).to receive(:proof).once

          subject.call(
            input:,
            result:,
            next_plugin: next_plugin_expecting(
              instant_verify: {
                address_of_residence: address_of_residence_result,
              },
            ),
          )
        end

        context 'when address_of_residence already in result' do
          let(:prior_address_of_residence_result) { address_of_residence_result }

          it 'does not make an api call' do
            expect(proofer).not_to receive(:proof)

            subject.call(
              input:,
              result:,
              next_plugin: next_plugin_expecting(
                instant_verify: {
                  address_of_residence: address_of_residence_result,
                },
              ),
            )
          end

          context 'but it is an exception' do
            let(:prior_address_of_residence_result) do
              Proofing::Resolution::Result.new(
                success: false,
                exception: :oh_no,
              )
            end

            it 'makes an api call' do
              expect(proofer).to receive(:proof)

              subject.call(
                input:,
                result:,
                next_plugin: next_plugin_expecting(
                  instant_verify: {
                    address_of_residence: address_of_residence_result,
                  },
                ),
              )
            end
          end
        end
      end
    end

    context 'when state_id.address same as address_of_residence' do
      let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

      it 'verifies the address only once' do
        expect(proofer).to receive(:proof).once

        subject.call(
          input:,
          result:,
          next_plugin: next_plugin_expecting(
            instant_verify: {
              address_of_residence: address_of_residence_result,
              state_id_address: address_of_residence_result,
            },
          ),
        )
      end

      context 'when address_of_residence already in result' do
        let(:prior_address_of_residence_result) { Proofing::Resolution::Result.new(success: true) }

        it 'does not make an api call and reuses prior result' do
          expect(proofer).not_to receive(:proof)

          subject.call(
            input:,
            result:,
            next_plugin: next_plugin_expecting(
              instant_verify: {
                address_of_residence: prior_address_of_residence_result,
                state_id_address: prior_address_of_residence_result,
              },
            ),
          )
        end

        context 'but it is an exception' do
          it 'makes an api call'
        end
      end

      context 'when state_id_address already in result' do
        it 'does not make an api call'
        it 'reuses the state_id_address result for both'
        context 'but it is an exception' do
          it 'makes an api call'
        end
      end

      context 'when state_id_address and address_of_residence already in result' do
        context 'and they agree' do
          it 'does not make an api call'
          it 'reuses the state_id_address result for both'
          context 'but it is an exception' do
            it 'makes an api call'
          end
        end
        context 'and they disagree' do
          it 'makes an api call'
        end
      end
    end

    context 'when state_id.address differs from address_of_residence' do
      let(:pii) do
        Idp::Constants::MOCK_IDV_APPLICANT.merge(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS)
      end

      it 'verifies both addresses' do
        expect(proofer).to receive(:proof).twice

        subject.call(
          input:,
          result:,
          next_plugin: next_plugin_expecting(
            instant_verify: {
              state_id_address: state_id_address_result,
              address_of_residence: address_of_residence_result,
            },
          ),
        )
      end

      context 'and address_of_residence fails verification' do
        let(:address_of_residence_result) do
          Proofing::Resolution::Result.new(
            success: false,
          )
        end

        it 'does not bother verifying state_id.address' do
          expect(proofer).to receive(:proof).once

          subject.call(
            input:,
            result:,
            next_plugin: next_plugin_expecting(
              instant_verify: {
                address_of_residence: address_of_residence_result,
              },
            ),
          )
        end
      end

      context 'when address_of_residence already in result' do
        it 'does not make an api call'
        it 'reuses the address_of_residence result for both'
        context 'but it is an exception' do
          it 'makes an api call'
        end
      end

      context 'when state_id_address already in result' do
        it 'does not make an api call'
        it 'reuses the state_id_address result for both'
        context 'but it is an exception' do
          it 'makes an api call'
        end
      end

      context 'when state_id_address and address_of_residence already in result' do
        context 'and they do not agree' do
          it 'makes a new API call to verify both addresses'
        end
        context 'and they agree' do
          it 'does not make an api call'
          it 'reuses the state_id_address result for both'
          context 'but it is an exception' do
            it 'makes an api call'
          end
        end
      end
    end
  end

  def next_plugin_expecting(*args, **kwargs)
    next_plugin = spy
    expect(next_plugin).to receive(:call).with(*args, **kwargs)
    next_plugin
  end

  def resolution_result_with(**attributes)
    satisfy do |value|
      expect(value).to be_an_instance_of(Proofing::Resolution::Result)
      expect(value).to have_attributes(**attributes)
    end
  end
end
