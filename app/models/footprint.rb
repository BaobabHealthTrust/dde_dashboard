class Footprint < CouchRest::Model::Base
  
  use_database "person"
 
  property :npid, String
  property :application, String
  property :site_code, String
  property :origin, String
  
  timestamps!

  design do
    view :by__id

    view :where_gone,
       :map => "function(doc) {
            if (doc['type'] == 'Footprint') {
              emit(doc.npid, {application: doc.application, site: doc.site_code, when: doc.updated_at});
            }
          }"

    view :existing,
       :map => "function(doc) {
            if (doc['type'] == 'Footprint') {
              emit([doc.npid, doc.application, doc.site_code, (new Date(doc.updated_at)).getFullYear(), ((new Date(doc.updated_at)).getMonth() + 1), (new Date(doc.updated_at)).getDate()], {application: doc.application, site: doc.site_code, when: doc.updated_at});
            }
          }"
          
    view :by_site,
       :map => "function(doc) {
            if (doc['type'] == 'Footprint') {
              emit(doc.site_code, {application: doc.application, site: doc.site_code, when: doc.updated_at});
            }
          }"

    view :by_origin,
       :map => "function(doc) {
            if (doc['type'] == 'Footprint') {
              emit([doc.origin, doc.site_code], {npid: doc.npid, application: doc.application, site: doc.site_code, when: doc.updated_at});
            }
          }"

    view :by_migration,
       :map => "function(doc) {
            if (doc['type'] == 'Footprint' && doc.origin != doc.site_code && doc.origin != null) {
              emit([doc.origin, doc.site_code], {npid: doc.npid, application: doc.application, site: doc.site_code, when: doc.updated_at});
            }
          }"

  end

end
