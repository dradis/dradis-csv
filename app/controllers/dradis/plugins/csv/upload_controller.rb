module Dradis::Plugins::CSV
  class UploadController < ::AuthenticatedController
    include ProjectScoped

    before_action :load_attachment, only: [:new, :create]
    before_action :load_rtp_fields, only: [:new]
    before_action :load_csv_headers, only: [:new]

    # Reached after the standard upload flow has already run the file
    # through Importer#import. If a saved mapping matched, that import
    # already happened (see importer.rb) and there's nothing left to map.
    def new
      if saved_mapping?
        return redirect_to main_app.project_issues_path(current_project),
          notice: 'CSV imported using its saved mapping.'
      end

      @default_columns = ['Column Header', 'Entity', 'Dradis Field']
      @log_uid = Log.new.uid
    end

    def create
      save_mapping

      job_logger.write 'Enqueueing job to start in the background.'

      MappingImportJob.perform_later(
        default_user_id: current_user.id,
        file: @attachment.fullpath.to_s,
        headers: csv_headers,
        mappings: mappings_params[:field_attributes].to_h,
        project_id: current_project.id,
        state: state,
        uid: params[:log_uid].to_i
      )
    end

    private

    def job_logger
      @job_logger ||= Log.new(uid: params[:log_uid].to_i)
    end

    def csv_headers
      @csv_headers ||= ::CSV.open(@attachment.fullpath, &:readline)
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

    def rtp_destination
      rtp = current_project.report_template_properties
      rtp && rtp.as_mapping_destination
    end

    # Persist the submitted column assignments so future uploads of this CSV
    # format can reuse them. Mappings are scoped to a report template, so
    # projects without one keep the upload-time mapper only.
    def save_mapping
      return unless rtp_destination

      MappingBuilder.new(
        column_mappings: mappings_params[:field_attributes].to_h,
        destination: rtp_destination,
        headers: csv_headers
      ).save
    end

    def saved_mapping?
      return false unless rtp_destination

      sources = %i[issue evidence].map do |entity|
        Dradis::Plugins::CSV.mapping_source(headers: @headers, entity: entity)
      end

      ::Mapping.exists?(
        component: Dradis::Plugins::CSV.component,
        source: sources,
        destination: rtp_destination
      )
    end

    def state
      @state ||=
        Issue.states.key?(params[:state]) ? params[:state] : 'draft'
    end
  end
end
