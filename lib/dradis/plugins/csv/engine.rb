module Dradis::Plugins::CSV
  class Engine < ::Rails::Engine
    isolate_namespace Dradis::Plugins::CSV

    include ::Dradis::Plugins::Base
    description 'Processes CSV output'
    provides :addon, :upload

    initializer 'csv.mount_engine' do
      Rails.application.routes.append do
        mount Dradis::Plugins::CSV::Engine => '/', as: :csv
      end
    end
  end
end
