require 'rails_helper'

RSpec.describe Idv::StateIdForm do
  let(:subject) { Idv::StateIdForm.new(pii) }
  let(:valid_dob) do
    valid_d = Time.zone.today - IdentityConfig.store.idv_min_age_years.years - 1.day
    ActionController::Parameters.new(
      year: valid_d.year,
      month: valid_d.month,
      day: valid_d.mday,
    ).permit(:year, :month, :day)
  end
  let(:too_young_dob) do
    dob = Time.zone.today - IdentityConfig.store.idv_min_age_years.years + 1.day
    ActionController::Parameters.new(
      year: dob.year,
      month: dob.month,
      day: dob.mday,
    ).permit(:year, :month, :day)
  end
  let(:valid_exp) do
    valid_d = Time.zone.today + 2.days
    ActionController::Parameters.new(
      year: valid_d.year,
      month: valid_d.month,
      day: valid_d.mday,
    ).permit(:year, :month, :day)
  end
  let(:expired_exp) do
    dob = Time.zone.today
    ActionController::Parameters.new(
      year: dob.year,
      month: dob.month,
      day: dob.mday,
    ).permit(:year, :month, :day)
  end
  let(:same_address_as_id) { 'true' }
  let(:first_name) { Faker::Name.first_name }
  let(:dob) { valid_dob }
  let(:id_expiration) { valid_exp }
  let(:params) do
    {
      first_name:,
      last_name: Faker::Name.last_name,
      dob:,
      identity_doc_address1: Faker::Address.street_address,
      identity_doc_address2: Faker::Address.secondary_address,
      identity_doc_city: Faker::Address.city,
      identity_doc_zipcode: Faker::Address.zip_code,
      identity_doc_address_state: Faker::Address.state_abbr,
      same_address_as_id:,
      state_id_jurisdiction: 'AL',
      state_id_number: Faker::IdNumber.valid,
      id_expiration:,
    }
  end
  let(:invalid_char) { '1' }
  let(:dob_min_age_name_error_params) do
    params.merge(
      first_name: Faker::Name.first_name + invalid_char,
      dob: too_young_dob,
    )
  end
  let(:expired_params) { params.merge(id_expiration: expired_exp) }
  let(:name_error_params) { params.merge(first_name: Faker::Name.first_name + invalid_char) }
  let(:pii) { nil }
  describe '#submit' do
    let(:result) { subject.submit(params) }

    context 'when the form is valid' do
      let(:form_response) do
        FormResponse.new(
          success: true,
          errors: {},
          extra: { birth_year: valid_dob[:year],
                   document_zip_code: params[:identity_doc_zipcode].slice(0, 5) },
        )
      end

      it 'returns a successful form response' do
        expect(result).to eq(form_response)
      end

      it 'logs extra analytics attributes' do
        expect(result.extra).to eq(
          {
            birth_year: valid_dob[:year],
            document_zip_code: params[:identity_doc_zipcode].slice(0, 5),
          },
        )
      end
    end

    context 'when there is an error with name' do
      let(:first_name) { Faker::Name.first_name + invalid_char }

      it 'returns a single name error when name is wrong' do
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(subject.errors.empty?).to be(false)
        expect(subject.errors[:first_name]).to eq [
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: [invalid_char].join(', '),
          ),
        ]
        expect(result.errors.empty?).to be(true)
      end

      context 'also when the user is too young' do
        let(:dob) { too_young_dob }

        it 'returns both name and dob error when both fields are invalid' do
          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(false)
          expect(subject.errors.empty?).to be(false)
          expect(subject.errors[:first_name]).to eq [
            I18n.t(
              'in_person_proofing.form.state_id.errors.unsupported_chars',
              char_list: [invalid_char].join(', '),
            ),
          ]
          expect(subject.errors[:dob]).to eq [
            I18n.t(
              'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
              app_name: APP_NAME,
            ),
          ]
        end
      end
    end

    context 'when the ID is expired' do
      let(:id_expiration) { expired_exp }

      it 'returns both expired error' do
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(subject.errors.empty?).to be(false)
        expect(subject.errors[:id_expiration]).to eq [
          I18n.t(
            'in_person_proofing.form.state_id.memorable_date.errors.expiration_date.expired',
            app_name: APP_NAME,
          ),
        ]
      end
    end

    context 'when the same_address_as_id field is missing' do
      let(:same_address_as_id) { nil }

      it 'returns an error' do
        expect(result.success?).to eq(false)
        expect(subject.errors.empty?).to be(false)
        expect(subject.errors[:same_address_as_id]).to eq [
          I18n.t('errors.messages.missing_field'),
        ]
      end
    end

    context 'expiration edge cases (LG-17733)' do
      let(:placeholder_9s) do
        ActionController::Parameters.new(year: '9999', month: '99', day: '99')
          .permit(:year, :month, :day)
      end
      let(:placeholder_0s) do
        ActionController::Parameters.new(year: '0000', month: '00', day: '00')
          .permit(:year, :month, :day)
      end

      context 'when the feature flag is enabled' do
        before do
          allow(IdentityConfig.store)
            .to receive(:in_person_proofing_expiration_edge_cases_enabled).and_return(true)
        end

        context 'when a non-date option is selected' do
          %w[military indefinite none].each do |option|
            context "option #{option}" do
              let(:params) do
                super().except(:id_expiration).merge(id_expiration_option: option)
              end

              it 'is valid without an expiration date' do
                expect(result.success?).to eq(true)
                expect(subject.errors[:id_expiration]).to be_empty
              end
            end
          end
        end

        context 'when option is date with a literal placeholder value' do
          let(:params) do
            super().merge(id_expiration_option: 'date', id_expiration:)
          end

          context '99/99/9999' do
            let(:id_expiration) { placeholder_9s }

            it 'is valid' do
              expect(result.success?).to eq(true)
            end
          end

          context '00/00/0000' do
            let(:id_expiration) { placeholder_0s }

            it 'is valid' do
              expect(result.success?).to eq(true)
            end
          end
        end

        context 'when option is date with a real future date' do
          let(:params) { super().merge(id_expiration_option: 'date', id_expiration: valid_exp) }

          it 'is valid' do
            expect(result.success?).to eq(true)
          end
        end

        context 'when option is date with an expired date' do
          let(:params) { super().merge(id_expiration_option: 'date', id_expiration: expired_exp) }

          it 'returns the expired error' do
            expect(result.success?).to eq(false)
            expect(subject.errors[:id_expiration]).to eq [
              I18n.t(
                'in_person_proofing.form.state_id.memorable_date.errors.expiration_date.expired',
                app_name: APP_NAME,
              ),
            ]
          end
        end

        context 'when an invalid option is selected' do
          let(:params) { super().except(:id_expiration).merge(id_expiration_option: 'bogus') }

          it 'is invalid' do
            expect(result.success?).to eq(false)
            expect(subject.errors[:id_expiration_option]).to be_present
          end
        end
      end

      context 'when the feature flag is disabled' do
        before do
          allow(IdentityConfig.store)
            .to receive(:in_person_proofing_expiration_edge_cases_enabled).and_return(false)
        end

        context 'and a literal placeholder date is entered' do
          let(:params) { super().merge(id_expiration: placeholder_9s) }

          it 'is rejected as an invalid/expired date' do
            expect(result.success?).to eq(false)
            expect(subject.errors[:id_expiration]).to be_present
          end
        end
      end
    end
  end
end
