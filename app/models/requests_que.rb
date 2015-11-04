class RequestsQue < CouchRest::Model::Base

  use_database "local"
    
  property :site_code, String
  property :region, String
  property :threshold, Integer
  property :request_processed, TrueClass, :default => false
  
  timestamps!

  design do
    view :by__id
    
    view :pending,
         :map => "function(doc){
            if (doc['type'] == 'RequestsQue' && doc['request_processed'] == false && doc['region'] != null){
                  emit(doc.site_code, null);
            }
          }"
  end

end
