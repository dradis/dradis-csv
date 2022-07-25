module Dradis::Plugins::CSV
  class UploadController < ::AuthenticatedController
    include ProjectScoped

    before_action :load_attachment, only: [:new, :create]
    before_action :load_rtp_fields, only: [:new]

    def new
      @default_columns = ['Column Header', 'Entity', 'Dradis Field']

      @headers = ::CSV.open(@attachment.fullpath, &:readline)

      @log_uid = Log.new.uid
    end

    def create
      job_logger.write 'Enqueueing job to start in the background.'

      MappingImportJob.perform_later(
        file: @attachment.fullpath.to_s,
        mappings: mappings_params[:field_attributes].to_h,
        project_id: current_project.id,
        uid: params[:log_uid].to_i
      )

      Resque.redis.del(Importer::REDIS_PREFIX + params[:job_id])
    end

    private

    def job_logger
      @job_logger ||= Log.new(uid: params[:log_uid].to_i)
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

    def load_attachment
      if Integer(params[:job_id], exception: false) && Resque.redis.get(Importer::REDIS_PREFIX + params[:job_id]).present?
        filename = Resque.redis.get(Importer::REDIS_PREFIX + params[:job_id])
        @attachment = Attachment.find(filename, conditions: { node_id: current_project.plugin_uploads_node.id })
      else
        redirect_to main_app.project_upload_path, alert: 'Something fishy is going on...'
      end
    end

    def mappings_params
      params.require(:mappings).permit(field_attributes: [:field, :type])
    end
  end
end
