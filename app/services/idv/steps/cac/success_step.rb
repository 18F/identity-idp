module Idv
  module Steps
    module Cac
    class SuccessStep < DocAuthBaseStep
      def call
        pii_from_doc = {
          first_name: 'Jane',
          middle_name: 'Ann',
          last_name: 'Doe',
          address1: '1 Street',
          city: 'New York',
          state: 'NY',
          zipcode: '11364',
          dob: '10/05/1938',
          ssn: '900-33-2222',
          phone: '456',
        }.freeze

        idv_session['profile_confirmation'] = true
        idv_session['vendor_phone_confirmation'] = false
        idv_session['user_phone_confirmation'] = false
        idv_session['address_verification_mechanism'] = 'phone'
        idv_session['resolution_successful'] = 'phone'

        idv_session['params'] = pii_from_doc
        idv_session['applicant'] = pii_from_doc
        idv_session['applicant']['uuid'] = current_user.uuid
      end
    end
    end
  end
end
