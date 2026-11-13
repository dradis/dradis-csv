require 'rails_helper'

# To run, execute from Dradis main app folder:
#   bin/rspec [dradis-plugins path]/spec/requests/upload_spec.rb

describe 'CSV upload requests' do
  let(:attachments_path) { Attachment.pwd.join(@project.plugin_uploads_node.id.to_s) }
  let(:file_path) { File.expand_path('../fixtures/files/simple.csv', __dir__) }

  before do
    login_to_project_as_user

    FileUtils.mkdir_p(attachments_path)
    FileUtils.cp(file_path, attachments_path.join('simple.csv'))
  end

  after { FileUtils.rm_rf(attachments_path) }

  describe 'POST #create' do
    it 'keeps the console job id as given, so the console only shows this import' do
      log_uid = SecureRandom.uuid

      expect do
        post csv.project_upload_index_path(@project), params: {
          attachment: 'simple.csv',
          format: :js,
          log_uid: log_uid,
          mappings: { field_attributes: { '0' => { type: 'identifier' } } }
        }
      end.to have_enqueued_job(Dradis::Plugins::CSV::MappingImportJob).with(hash_including(uid: log_uid))

      expect(Log.where(uid: log_uid).pluck(:text)).to include('Enqueueing job to start in the background.')
      expect(response.body).to include("ConsoleUpdater.jobId = '#{log_uid}';")
    end
  end
end
