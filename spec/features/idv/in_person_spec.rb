require 'rails_helper'

RSpec.describe 'In Person Proofing' do
  include DocAuthHelper
  include IdvHelper

  it 'works for a happy path', js: true do
    user = sign_in_and_2fa_user

    # welcome step
    visit idv_doc_auth_welcome_step # only thing used from DocAuthHelper
    click_idv_continue

    # information step
    click_on t('doc_auth.buttons.continue')
    find('label', text: t('doc_auth.instructions.consent', app_name: APP_NAME)).click

    click_on t('doc_auth.info.upload_computer_link')

    sleep 100

    # image upload step
    attach_images_that_fail
    click_idv_continue

    # clicking through continue for each IPP page
    click_link t('idv.troubleshooting.options.verify_in_person')
  end

  def attach_images_that_fail
    Tempfile.create(['ia2_mock', '.yml']) do |yml_file|
      yml_file.rewind
      yml_file.puts <<~YAML
        failed_alerts:
        - name: Some Made Up Error
      YAML
      yml_file.close

      attach_file t('doc_auth.headings.document_capture_front'), yml_file.path
      attach_file t('doc_auth.headings.document_capture_back'), yml_file.path
    end
  end
end
