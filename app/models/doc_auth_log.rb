class DocAuthLog < ApplicationRecord
  belongs_to :user

  # rubocop:disable Rails/InverseOf
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: doc_auth_logs
#
#  id                                     :bigint           not null, primary key
#  aamva                                  :boolean
#  agreement_view_at                      :datetime
#  agreement_view_count                   :integer          default(0)
#  back_image_error_count                 :integer          default(0)
#  back_image_submit_at                   :datetime
#  back_image_submit_count                :integer          default(0)
#  back_image_view_at                     :datetime
#  back_image_view_count                  :integer          default(0)
#  capture_complete_view_at               :datetime
#  capture_complete_view_count            :integer          default(0)
#  capture_mobile_back_image_error_count  :integer          default(0)
#  capture_mobile_back_image_submit_at    :datetime
#  capture_mobile_back_image_submit_count :integer          default(0)
#  capture_mobile_back_image_view_at      :datetime
#  capture_mobile_back_image_view_count   :integer          default(0)
#  choose_method_view_at                  :datetime
#  choose_method_view_count               :integer          default(0)
#  document_capture_error_count           :integer          default(0)
#  document_capture_submit_at             :datetime
#  document_capture_submit_count          :integer          default(0)
#  document_capture_view_at               :datetime
#  document_capture_view_count            :integer          default(0)
#  email_sent_view_at                     :datetime
#  email_sent_view_count                  :integer          default(0)
#  encrypt_view_at                        :datetime
#  encrypt_view_count                     :integer          default(0)
#  enter_info_view_at                     :datetime
#  enter_info_view_count                  :integer          default(0)
#  front_image_error_count                :integer          default(0)
#  front_image_submit_count               :integer          default(0)
#  front_image_view_at                    :datetime
#  front_image_view_count                 :integer          default(0)
#  issuer                                 :string
#  last_document_error                    :string
#  link_sent_view_at                      :datetime
#  link_sent_view_count                   :integer          default(0)
#  mobile_back_image_error_count          :integer          default(0)
#  mobile_back_image_submit_at            :datetime
#  mobile_back_image_submit_count         :integer          default(0)
#  mobile_back_image_view_at              :datetime
#  mobile_back_image_view_count           :integer          default(0)
#  mobile_front_image_error_count         :integer          default(0)
#  mobile_front_image_submit_count        :integer          default(0)
#  mobile_front_image_view_at             :datetime
#  mobile_front_image_view_count          :integer          default(0)
#  no_sp_session_started_at               :datetime
#  present_cac_error_count                :integer          default(0)
#  present_cac_submit_count               :integer          default(0)
#  present_cac_view_at                    :datetime
#  present_cac_view_count                 :integer          default(0)
#  selfie_error_count                     :integer          default(0)
#  selfie_submit_count                    :integer          default(0)
#  selfie_view_at                         :datetime
#  selfie_view_count                      :integer          default(0)
#  send_link_view_at                      :datetime
#  send_link_view_count                   :integer          default(0)
#  ssn_view_at                            :datetime
#  ssn_view_count                         :integer          default(0)
#  state                                  :string
#  success_view_at                        :datetime
#  success_view_count                     :integer          default(0)
#  upload_view_at                         :datetime
#  upload_view_count                      :integer          default(0)
#  usps_address_view_at                   :datetime
#  usps_address_view_count                :integer          default(0)
#  usps_letter_sent_error_count           :integer          default(0)
#  usps_letter_sent_submit_count          :integer          default(0)
#  verified_view_at                       :datetime
#  verified_view_count                    :integer          default(0)
#  verify_error_count                     :integer          default(0)
#  verify_phone_submit_at                 :datetime
#  verify_phone_submit_count              :integer          default(0)
#  verify_phone_view_at                   :datetime
#  verify_phone_view_count                :integer          default(0)
#  verify_submit_at                       :datetime
#  verify_submit_count                    :integer          default(0)
#  verify_view_at                         :datetime
#  verify_view_count                      :integer          default(0)
#  welcome_view_at                        :datetime
#  welcome_view_count                     :integer          default(0)
#  created_at                             :datetime         not null
#  updated_at                             :datetime         not null
#  user_id                                :integer          not null
#
# Indexes
#
#  index_doc_auth_logs_on_issuer            (issuer)
#  index_doc_auth_logs_on_user_id           (user_id) UNIQUE
#  index_doc_auth_logs_on_verified_view_at  (verified_view_at)
#
# rubocop:enable Layout/LineLength
