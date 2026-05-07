module Dradis::Plugins::CSV
  class UploadController < ::AuthenticatedController
    include ProjectScoped

    before_action :load_attachment, only: [:new, :create]
    before_action :load_rtp_fields, only: [:new]
    before_action :load_csv_headers, only: [:new]
    before_action :load_saved_mappings, only: [:new]

    def new
      @default_columns = ['Column Header', 'Entity', 'Dradis Field']

      @log_uid = Log.new.uid
    end

    def create
      save_csv_mapping if save_mapping?

      job_logger.write 'Enqueueing job to start in the background.'

      MappingImportJob.perform_later(
        default_user_id: current_user.id,
        file: @attachment.fullpath.to_s,
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

    def load_saved_mappings
      @saved_mappings = defined?(::Mapping) ? ::Mapping.where(component: 'csv').includes(:mapping_fields) : []
    end

    def build_mapping_fields(mapping, headers)
      mappings_params[:field_attributes].each do |index, attrs|
        type = attrs['type']
        header = headers[index.to_i]

        next if type == 'skip' || header.blank?

        destination_field = destination_field_for(type, attrs['field'], attrs['custom_field'])
        next if destination_field.blank?

        ::MappingField.create!(
          content: header,
          destination_field: destination_field,
          mapping: mapping,
          source_field: header
        )
      end
    end

    def destination_field_for(type, field, custom_field = nil)
      name = field == 'Custom Field' ? custom_field : field
      case type
      when 'node'       then 'Node Label'
      when 'identifier' then 'Issue ID'
      when 'issue'      then "Issue: #{name}" if name.present?
      when 'evidence'   then "Evidence: #{name}" if name.present?
      else field
      end
    end

    def mappings_params
      params.require(:mappings).permit(field_attributes: %i[custom_field field type])
    end

    def save_csv_mapping
      return unless defined?(::Mapping)

      rtp = current_project.report_template_properties
      return unless rtp

      mapping = ::Mapping.find_or_initialize_by(
        component: 'csv',
        source: params[:mapping_source_name]
      )
      mapping.destination = "rtp_#{rtp.id}"
      return unless mapping.save

      mapping.mapping_fields.destroy_all
      build_mapping_fields(mapping, ::CSV.open(@attachment.fullpath, &:readline))
    end

    def save_mapping?
      params[:save_mapping] == '1' && params[:mapping_source_name].present?
    end

    def state
      @state ||=
        Issue.states.key?(params[:state]) ? params[:state] : 'draft'
    end
  end
end
