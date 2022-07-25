module Dradis::Plugins::CSV
  class Importer < Dradis::Plugins::Upload::Importer
    REDIS_PREFIX = 'addons-csv-upload-'.freeze

    def self.templates
      {}
    end

    def import(params={})
      logger.info { 'Uploading CSV file...' }

      uid = @logger.uid

      # SEE: app/controllers/dradis/plugins/csv/upload_controller.rb
      Resque.redis.set(REDIS_PREFIX + uid.to_s, File.basename(params[:file]))

      logger.info { 'Done' }
    end
  end
end
