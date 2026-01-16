require 'rails_helper'

RSpec.describe Idv::InPerson::PassportForm do
  let(:valid_dob) do
    valid_d = Time.zone.today - IdentityConfig.store.idv_min_age_years.years - 1.day
    ActionController::Parameters.new(
      {
        year: valid_d.year,
        month: valid_d.month,
        day: valid_d.mday,
      },
    ).permit(:year, :month, :day)
  end

  let(:valid_expiration_date) do
    valid_d = Time.zone.today + 1.year
    ActionController::Parameters.new(
      {
        year: valid_d.year,
        month: valid_d.month,
        day: valid_d.mday,
      },
    ).permit(:year, :month, :day)
  end

  describe 'submit' do
    let(:params) do
      {
        passport_surname: Faker::Name.last_name,
        passport_first_name: Faker::Name.first_name,
        passport_dob: valid_dob,
        passport_number: '123456789',
        passport_expiration: valid_expiration_date,
      }
    end

    context 'when the params are valid' do
      let(:successful_response) do
        FormResponse.new(
          success: true,
          errors: {},
          extra: {},
        )
      end

      it 'returns a successful form response' do
        expect(subject.submit(params)).to eq(successful_response)
      end
    end

    context 'when the params are invalid' do
      context 'when the surname is invalid' do
        let(:surname) { 'Testing1234' }

        let(:surname_errors) do
          [
            I18n.t(
              'in_person_proofing.form.state_id.errors.unsupported_chars',
              char_list: %w[1 2 3 4].join(', '),
            ),
          ]
        end

        let(:failure_response) do
          FormResponse.new(
            success: false,
            errors: {
              passport_surname: surname_errors,
            },
            extra: {},
          )
        end

        before do
          params[:passport_surname] = surname
        end

        it 'returns a failure form response' do
          expect(subject.submit(params)).to eq(failure_response)
        end
      end

      context 'when the first name is invalid' do
        let(:first_name) { 'Testing1234' }

        let(:first_name_errors) do
          [
            I18n.t(
              'in_person_proofing.form.state_id.errors.unsupported_chars',
              char_list: %w[1 2 3 4].join(', '),
            ),
          ]
        end

        let(:failure_response) do
          FormResponse.new(
            success: false,
            errors: {
              passport_first_name: first_name_errors,
            },
            extra: {},
          )
        end

        before do
          params[:passport_first_name] = first_name
        end

        it 'returns a failure form response' do
          expect(subject.submit(params)).to eq(failure_response)
        end
      end

      context 'when the date of birth is invalid' do
        let(:date_of_birth) do
          date = Time.zone.today - IdentityConfig.store.idv_min_age_years.years + 1.day
          ActionController::Parameters.new(
            {
              year: date.year,
              month: date.month,
              day: date.mday,
            },
          ).permit(:year, :month, :day)
        end

        let(:passport_dob_errors) do
          [
            I18n.t(
              'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
              app_name: APP_NAME,
            ),
          ]
        end

        let(:failure_response) do
          FormResponse.new(
            success: false,
            errors: {
              passport_dob: passport_dob_errors,
            },
            extra: {},
          )
        end

        before do
          params[:passport_dob] = date_of_birth
        end

        it 'returns a failure form response' do
          expect(subject.submit(params)).to eq(failure_response)
        end
      end

      context 'when the passport number is invalid' do
        context 'when the passport number is not nine characters long' do
          let(:passport_number) { '12345' }

          let(:errors) do
            [
              I18n.t('in_person_proofing.form.passport.errors.passport_number.pattern_mismatch'),
            ]
          end

          let(:failure_response) do
            FormResponse.new(
              success: false,
              errors: {
                passport_number: errors,
              },
              extra: {},
            )
          end

          before do
            params[:passport_number] = passport_number
          end

          it 'returns a failure form response' do
            expect(subject.submit(params)).to eq(failure_response)
          end
        end

        context 'when the passport number contains invalid symbols' do
          let(:passport_number) { '$12345678' }

          let(:errors) do
            [
              I18n.t('in_person_proofing.form.passport.errors.passport_number.pattern_mismatch'),
            ]
          end

          let(:failure_response) do
            FormResponse.new(
              success: false,
              errors: {
                passport_number: errors,
              },
              extra: {},
            )
          end

          before do
            params[:passport_number] = passport_number
          end

          it 'returns a failure form response' do
            expect(subject.submit(params)).to eq(failure_response)
          end
        end
      end

      context 'when the expiration date is invalid' do
        let(:expiration_date) do
          date = Time.zone.today - 1.day
          ActionController::Parameters.new(
            {
              year: date.year,
              month: date.month,
              day: date.mday,
            },
          ).permit(:year, :month, :day)
        end

        let(:errors) do
          [
            I18n.t(
              'in_person_proofing.form.passport.memorable_date.errors.expiration_date.expired',
            ),
          ]
        end

        let(:failure_response) do
          FormResponse.new(
            success: false,
            errors: {
              passport_expiration: errors,
            },
            extra: {},
          )
        end

        before do
          params[:passport_expiration] = expiration_date
        end

        it 'returns a failure form response' do
          expect(subject.submit(params)).to eq(failure_response)
        end
      end
    end
  end
end
