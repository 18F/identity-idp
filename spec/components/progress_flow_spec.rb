# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProgressFlow do
  describe '.find' do
    it 'resolves a mapped sign-up screen with default substep totals' do
      position = described_class.find('sign_up/passwords#new')

      expect(position).to have_attributes(
        step: 0,
        substep: 2,
        substeps: 2,
        gate: :none,
      )
      expect(position.flow.name).to eq(:sign_up)
      expect(position.flow.step_keys).to eq(%i[create_account secure connect])
    end

    it 'gates MFA screens to account creation by default' do
      position = described_class.find('users/two_factor_authentication_setup#index')

      expect(position).to have_attributes(step: 1, substep: 1, substeps: 2)
      expect(position).to be_creation_gated
    end

    it 'returns nil for unmapped routes including IDV' do
      expect(described_class.find('users/sessions#new')).to be_nil
      expect(described_class.find('idv/welcome#show')).to be_nil
    end
  end

  describe 'sign-up route table lock' do
    let(:flow) { described_class.registry[:sign_up] }
    let(:routes) { flow.routes }

    # Compact position groups — keep keys in sync with ProgressFlow.define(:sign_up).
    # Adding a screen: one string in the map + one string in the matching group below.
    let(:expected) do
      expand_route_lock(
        flow,
        [0, 1] => %w[
          sign_up/registrations#new
          sign_up/registrations#create
          sign_up/emails#show
          sign_up/cancellations#new
        ],
        [0, 2] => %w[
          sign_up/passwords#new
          sign_up/passwords#create
          users/rules_of_use#new
          users/rules_of_use#create
        ],
        [1, 1] => %w[
          users/two_factor_authentication_setup#index
          users/two_factor_authentication_setup#create
          users/webauthn_setup#new
          users/webauthn_setup#confirm
          users/webauthn_platform_recommended#new
          users/webauthn_platform_recommended#create
          users/webauthn_setup_mismatch#show
          users/totp_setup#new
          users/totp_setup#confirm
          users/phone_setup#index
          users/phone_setup#create
          users/piv_cac_authentication_setup#new
          users/piv_cac_authentication_setup#submit_new_piv_cac
          users/piv_cac_authentication_setup#error
          users/piv_cac_recommended#show
          mfa_confirmation#show
          two_factor_authentication/otp_verification#show
          two_factor_authentication/otp_verification#create
        ],
        [1, 2] => %w[
          users/backup_code_setup#index
          users/backup_code_setup#new
          users/backup_code_setup#create
          users/backup_code_setup#confirm_backup_codes
          users/backup_code_setup#refreshed
        ],
      )
    end

    it 'locks every mapped route position' do
      expect(routes.keys).to match_array(expected.keys)

      expected.each do |key, attrs|
        expect(routes[key]).to eq(attrs), "unexpected position for #{key}"
      end
    end

    def expand_route_lock(flow, groups)
      groups.each_with_object({}) do |((step, substep), keys), memo|
        gate = step.zero? ? :none : :creation
        substeps = flow.step_substeps[step]
        attrs = { step:, substep:, substeps:, gate: }.freeze
        keys.each { |key| memo[key] = attrs }
      end
    end
  end

  describe ProgressFlow::Definition do
    subject(:flow) do
      described_class.new(
        :test,
        step_keys: %i[a b],
        i18n_scope: 'step_indicator.flows.sign_up',
        step_substeps: { a: 2 },
      )
    end

    it 'defaults substeps from the flow definition' do
      flow.map('x#y', step: 0, substep: 1)

      expect(flow.routes['x#y']).to include(substep: 1, substeps: 2)
    end

    it 'rejects out-of-range steps at definition time' do
      expect { flow.map('x#y', step: 3) }.to raise_error(ArgumentError, /step/)
    end

    it 'rejects substep without a resolvable total' do
      expect { flow.map('x#y', step: 1, substep: 1) }.to raise_error(ArgumentError, /substep/)
    end

    it 'rejects duplicate routes in a flow' do
      flow.map('x#y', step: 0)
      expect { flow.map('x#y', step: 0) }.to raise_error(ArgumentError, /duplicate/)
    end

    it 'rejects unknown step keys in substeps:' do
      expect do
        described_class.new(
          :test,
          step_keys: %i[a],
          i18n_scope: 'x',
          step_substeps: { missing: 2 },
        )
      end.to raise_error(ArgumentError, /unknown step/)
    end
  end
end
