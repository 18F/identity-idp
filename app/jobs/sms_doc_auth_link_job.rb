class SmsDocAuthLinkJob < ApplicationJob
  queue_as :sms
  include Rails.application.routes.url_helpers

  def perform(phone:, link:, app:)
    puts("link=#{link}")
    message = I18n.t(
      'jobs.sms_doc_auth_link_job.message',
      link: link,
      application: app,
    )
    TwilioService::Utils.new.send_sms(
      to: phone,
      body: message,
    )
  end
end
