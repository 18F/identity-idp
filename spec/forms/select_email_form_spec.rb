require 'rails_helper'

RSpec.describe SelectEmailForm do
  let(:user) { create(:user, :fully_registered, :with_multiple_emails) }
  let(:identity) { nil }
  let(:selected_email_id) {}
  let(:params) { { selected_email_id: } }
  subject(:form) { SelectEmailForm.new(**{ user:, identity: }.compact) }

  describe '#submit' do
    subject(:response) { form.submit(params) }

    context 'with valid parameters' do
      let(:selected_email_id) { user.confirmed_email_addresses.take.id }

      it 'is successful' do
        expect(response.to_h).to eq(success: true, selected_email_id:)
      end

      context 'with associated identity' do
        let(:identity) { create(:service_provider_identity, :consented, user:) }

        it 'updates linked email address' do
          expect { response }.to change { identity.reload.email_address_id }.
            from(nil).
            to(selected_email_id)
        end
      end
    end

    context 'with an invalid email id' do
      let(:selected_email_id) { nil }

      it 'is unsuccessful' do
        expect(response.to_h).to eq(
          success: false,
          error_details: { selected_email_id: { not_found: true } },
          selected_email_id:,
        )
      end

      context 'with present value that does not convert to numeric' do
        let(:selected_email_id) { true }

        it 'is unsuccessful without raising exception' do
          expect(response.to_h).to eq(
            success: false,
            error_details: { selected_email_id: { not_found: true } },
            selected_email_id: nil,
          )
        end
      end

      context 'with associated identity' do
        let(:identity) do
          create(
            :service_provider_identity,
            :consented,
            user:,
            email_address_id: user.confirmed_email_addresses.take.id,
          )
        end

        it 'does not update linked email address' do
          expect { response }.not_to change { identity.reload.email_address_id }
        end
      end
    end

    context 'with an unconfirmed email address added' do
      let(:selected_email_id) { user.email_addresses.find_by(confirmed_at: nil).id }

      before do
        create(:email_address, :unconfirmed, user:)
      end

      it 'is unsuccessful' do
        expect(response.to_h).to eq(
          success: false,
          error_details: { selected_email_id: { not_found: true } },
          selected_email_id:,
        )
      end

      context 'with associated identity' do
        let(:identity) { create(:service_provider_identity, :consented, user:) }

        it 'does not update linked email address' do
          expect { response }.not_to change { identity.reload.email_address_id }
        end
      end
    end

    context 'with another user\'s email' do
      let(:user2) { create(:user, :fully_registered, :with_multiple_emails) }
      let(:selected_email_id) { user2.confirmed_email_addresses.take.id }

      it 'is unsuccessful' do
        expect(response.to_h).to eq(
          success: false,
          error_details: { selected_email_id: { not_found: true } },
          selected_email_id:,
        )
      end

      context 'with associated identity' do
        let(:identity) { create(:service_provider_identity, :consented, user:) }

        it 'does not update linked email address' do
          expect { response }.not_to change { identity.reload.email_address_id }
        end
      end
    end
  end
end
