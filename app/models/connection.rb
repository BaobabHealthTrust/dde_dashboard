require 'couchrest_model'

class Connection < CouchRest::Model::Base

  use_database "person"
    
  # Combination of source site_code and sink site_code e.g. KCH-QEC for link between
  # site_code KCH and site_code QEC
  def src_sink=(value)
    self['_id']=value
  end

  def src_sink
      self['_id']
  end

  property :source, String  # Connection source
  property :sink, String    # Connection destination
 
  timestamps!

  design do
    view :by__id
    
    view :exists,
      :map => "function(doc){
            if (doc['type'] == 'Connection' && (doc['source'] != '' && doc['source'] != null) && (doc['sink'] != '' && doc['sink'] != null) ){
              emit([doc.source, doc.sink], {id: doc._id, source: doc.source, sink: doc.sink, created_at: doc.created_at, updated_at: doc.updated_at});
            }
          }"
  end

end
