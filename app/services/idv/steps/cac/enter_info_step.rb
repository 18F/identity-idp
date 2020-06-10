module Idv
  module Steps
    module Cac
      class EnterInfoStep < DocAuthBaseStep
        PII_FIELDS = %i[first_name last_name address1 address2 city state zipcode dob ssn].freeze

        def call
          store_info_in_session
        end

        private

        def store_info_in_session
          data = params[:doc_auth]
          flow_session[:pii_from_doc] = { 'uuid' => current_user.uuid }
          PII_FIELDS.each do |key|
            flow_session[:pii_from_doc][key] = data[key]
          end
        end

        def form_submit
          use_session_full_name_or_check_if_full_name_in_cn_and_set_session
          Idv::CacForm.new(user: current_user, previous_params: {}).submit(da_params, cn)
        end

        def use_session_full_name_or_check_if_full_name_in_cn_and_set_session
          da_params = params[:doc_auth]
          if flow_session['first_name'] && flow_session['last_name']
            use_full_name_from_session
          elsif PivCac::IsFullNameInCn.call(cn, da_params[:first_name], da_params[:last_name])
            update_session_with_full_name
          end
        end

        def use_full_name_from_session
          da_params[:first_name] = flow_session['first_name']
          da_params[:last_name] = flow_session['last_name']
        end

        def update_session_with_full_name
          flow_session['first_name'] = da_params[:first_name]
          flow_session['last_name'] = da_params[:last_name]
        end

        def da_params
          params[:doc_auth]
        end

        def cn
          flow_session['piv_cac_cn']
        end
      end
    end
  end
end
