module Dradis::Plugins::CSV
  class UploadController < ::AuthenticatedController
    include ProjectScoped

    before_action :load_attachment, only: [:new, :create]
    before_action :load_csv_headers, only: [:new]

    def new
      @default_columns = ['Column Header From File', 'Type', 'Field in Dradis']

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

      Resque.redis.del(Importer::REDIS_PREFIX + params[:job_id])
    end

    private

    def job_logger
      @job_logger ||= Log.new(uid: params[:log_uid].to_i)
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
