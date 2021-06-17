require 'date'
require 'hashie/mash'

module Proofing
  module Aamva
    class Applicant < Hashie::Mash
      def self.from_proofer_applicant(applicant)
        new(
          uuid: applicant[:uuid],
          first_name: applicant[:first_name],
          last_name: applicant[:last_name],
          dob: format_dob(applicant[:dob]),
          state_id_data: format_state_id_data(applicant),
        )
      end

      private_class_method def self.format_dob(dob)
        return dob if dob =~ /\A\d{4}-\d{2}-\d{2}\z/
        return '' if dob.nil? || dob == ''

        date = date_from_dob_string(dob)

        return '' if date.nil?
        date.strftime('%Y-%m-%d')
      end

      private_class_method def self.date_from_dob_string(dob_string)
        if dob_string =~ /\A\d{8}\z/
          Date.strptime(dob_string, '%Y%m%d')
        elsif dob_string =~ %r{\A\d{2}/\d{2}/\d{4}\z}
          Date.strptime(dob_string, '%m/%d/%Y')
        end
      end

      private_class_method def self.format_state_id_data(applicant)
        {
          state_id_number: applicant.dig(:state_id_number)&.gsub(/[^\w\d]/, ''),
          state_id_jurisdiction: applicant[:state_id_jurisdiction],
          state_id_type: applicant[:state_id_type],
        }
      end
    end
  end
end
