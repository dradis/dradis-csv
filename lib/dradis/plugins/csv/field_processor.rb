module Dradis::Plugins::CSV
  class FieldProcessor < Dradis::Plugins::Upload::FieldProcessor
    # data is a CSV::Row. Mapping fields reference columns by their
    # normalized header name (see Dradis::Plugins::CSV.normalize_header),
    # so we look up the matching column the same way.
    def value(args = {})
      field = args[:field]

      header = data.headers.find do |candidate|
        Dradis::Plugins::CSV.normalize_header(candidate) == field
      end

      header ? data[header].to_s : ''
    end
  end
end
