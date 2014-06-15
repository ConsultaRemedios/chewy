module Chewy
  class Query
    module Pagination
      def total_count
        _response['hits'].try(:[], 'total') || 0
      end
    end
  end
end

require 'chewy/query/pagination/proxy'

if defined?(::Kaminari)
  require 'chewy/query/pagination/kaminari'
  require 'chewy/query/pagination/kaminari_proxy'
end
