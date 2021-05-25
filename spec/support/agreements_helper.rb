module AgreementsHelper
  def clear_agreements_data
    Agreements::IntegrationUsage.delete_all
    Agreements::IaaOrder.delete_all
    Agreements::Integration.delete_all
    Agreements::IntegrationStatus.delete_all
    Agreements::IaaGtc.delete_all
    Agreements::PartnerAccount.delete_all
    Agreements::PartnerAccountStatus.delete_all
  end
end
