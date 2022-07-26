module Dradis::Plugins::CSV
  class MappingImportJob < ApplicationJob
    queue_as :dradis_project

    # mappings hash:
    # The key is the column index, while the value is a hash containing the type of resource (evidence/identifier/issue/node).
    # It's used to map a CSV header to a field in Dradis (only for evidence and issues).
    #
    # e.g.
    # {
    #   '0' => { 'type' => 'node' },
    #   '1' => { 'type' => 'issue', 'field' => 'Title' },
    #   '2' => { 'type' => 'identifier' },
    #   '3' => { 'type' => 'evidence', 'field' => 'Port' }
    # }
    def perform(default_user_id:, file:, mappings:, project_id:, uid:)
      logger = Log.new(uid: uid)
      logger.write { "Job id is #{job_id}." }

      importer = Importer.new(
        default_user_id: default_user_id,
        logger: logger,
        plugin: self.class.module_parent,
        project_id: project_id
      )

      importer.import_csv(file: file, mappings: mappings)

      logger.write { 'Worker process completed.' }
    end
  end
end
