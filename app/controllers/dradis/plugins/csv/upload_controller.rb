module Dradis::Plugins::CSV
  class UploadController < ::AuthenticatedController
    include ProjectScoped

    def new
      if Integer(params[:job_id], exception: false)
        filename = Resque.redis.get(Importer::REDIS_PREFIX + params[:job_id])
        @attachment = Attachment.find(filename, conditions: { node_id: current_project.plugin_uploads_node.id })
      else
        redirect_to main_app.project_upload_path, alert: 'Something fishy is going on...'
      end
    end
  end
end
