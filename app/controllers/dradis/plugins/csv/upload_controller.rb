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
      @attachment = Attachment.find(params[:attachment], conditions: { node_id: current_project.plugin_uploads_node.id })
    end
  end
end
