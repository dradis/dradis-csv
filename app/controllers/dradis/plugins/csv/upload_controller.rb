module Dradis::Plugins::CSV
  class UploadController < ::AuthenticatedController
    include ProjectScoped

    before_action :load_attachment, only: [:new, :create]
    before_action :load_rtp_fields, only: [:new]
    before_action :load_csv_headers, only: [:new]

    def new
      @default_columns = ['Column Header', 'Entity', 'Dradis Field']

      @log_uid = Log.new.uid
    end

    def create
      job_logger.write 'Enqueueing job to start in the background.'

      MappingImportJob.perform_later(
        default_user_id: current_user.id,
        file: @attachment.fullpath.to_s,
        mappings: mappings_params[:field_attributes].to_h,
        project_id: current_project.id,
        uid: params[:log_uid].to_i
      )
    end

    private

    def job_logger
      @job_logger ||= Log.new(uid: params[:log_uid].to_i)
    end

    def load_attachment
      filename = CGI::escape params[:attachment]
      @attachment = Attachment.find(filename, conditions: { node_id: current_project.plugin_uploads_node.id })
    end

    def load_csv_headers
      begin
        unless File.extname(@attachment.fullpath) == '.csv'
          raise Dradis::Plugins::CSV::FileExtensionError
        end

        @headers = ::CSV.open(@attachment.fullpath, &:readline)
      rescue CSV::MalformedCSVError => e
        return redirect_to main_app.project_upload_manager_path, alert: "The uploaded file is not a valid CSV file: #{e.message}"
      rescue Dradis::Plugins::CSV::FileExtensionError
        return redirect_to main_app.project_upload_manager_path, alert: "The uploaded file is not a CSV file."
      end
    end

    def load_rtp_fields
      rtp = current_project.report_template_properties
      @rtp_fields =
        unless rtp.nil?
          {
            evidence: rtp.evidence_fields.map(&:name),
            issue: rtp.issue_fields.map(&:name)
          }
        end
    end

    def mappings_params
      params.require(:mappings).permit(field_attributes: [:field, :type])
    end
  end
end
