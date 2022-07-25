module Dradis::Plugins::CSV
  class UploadController < ::AuthenticatedController
    include ProjectScoped

    before_action :load_attachment, only: [:new]

    def new
      @default_columns = ['Column Header From File', 'Type', 'Field in Dradis']

      @headers = ::CSV.open(@attachment.fullpath, &:readline)
    end

    def create
      redirect_to main_app.project_upload_manager_path(current_project)
    end

    private

    def load_attachment
      if Integer(params[:job_id], exception: false)
        filename = Resque.redis.get(Importer::REDIS_PREFIX + params[:job_id])
        @attachment = Attachment.find(filename, conditions: { node_id: current_project.plugin_uploads_node.id })
      else
        redirect_to main_app.project_upload_path, alert: 'Something fishy is going on...'
      end
    end
  end
end
