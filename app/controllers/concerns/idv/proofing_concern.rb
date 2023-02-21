module Idv
  module ProofingConcern
    extend ActiveSupport::Concern

    def should_use_aamva?(pii)
      aamva_state?(pii) && !aamva_disallowed_for_service_provider?
    end

    def aamva_state?(pii)
      IdentityConfig.store.aamva_supported_jurisdictions.include?(
        pii['state_id_jurisdiction'],
      )
    end

    def aamva_disallowed_for_service_provider?
      return false if sp_session.nil?
      banlist = IdentityConfig.store.aamva_sp_banlist_issuers
      banlist.include?(sp_session[:issuer])
    end

    def add_proofing_costs(results)
      results[:context][:stages].each do |stage, hash|
        if stage == :resolution
          # transaction_id comes from ConversationId
          add_cost(:lexis_nexis_resolution, transaction_id: hash[:transaction_id])
        elsif stage == :state_id
          next if hash[:vendor_name] == 'UnsupportedJurisdiction'
          process_aamva(hash[:transaction_id])
        elsif stage == :threatmetrix
          # transaction_id comes from request_id
          tmx_id = hash[:transaction_id]
          add_cost(:threatmetrix, transaction_id: tmx_id) if tmx_id
        end
      end
    end

    def process_aamva(transaction_id)
      # transaction_id comes from TransactionLocatorId
      add_cost(:aamva, transaction_id: transaction_id)
      track_aamva
    end

    def track_aamva
      return unless IdentityConfig.store.state_tracking_enabled
      doc_auth_log = DocAuthLog.find_by(user_id: current_user.id)
      return unless doc_auth_log
      doc_auth_log.aamva = true
      doc_auth_log.save!
    end

    def add_cost(token, transaction_id: nil)
      Db::SpCost::AddSpCost.call(current_sp, 2, token, transaction_id: transaction_id)
    end
  end
end
