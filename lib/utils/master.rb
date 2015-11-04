module Utils

  class Master
    
    @@npid_mutex = nil
    
    def initialize
      
      @@npid_mutex = Mutex.new if @@npid_mutex.nil?
    
    end
    
=begin
  + assign_npids_to_site(
      site:String, quantity:Integer
    ):BOOLEAN
  
  Given a site code and the number of ids to assign, this function aims at assigning 
  the given range of ids to the given site.
  
  An example would be given a site with code 'MLS' which has to be assigned 10 ids,
  given the last assigned id was 20, the new ids to be assigned are from 21 to 31.
=end
    def self.assign_npids_to_site(code, quantity)
    
      raise "First argument cannot be blank" if code.to_s.strip.match(/^$/)
      
      raise "Second argument is supposed to be an integer" if !quantity.to_s.match(/^\d+$/)
    
      @@npid_mutex = Mutex.new if @@npid_mutex.nil?
    
      @@npid_mutex.synchronize do
        
        i = 0 
        
        site = Site.find_by__id(code) rescue nil
        
        if !site.nil?
          case site.region.downcase
            when "centre"                     
              npids = []
              
              Npid.unassigned_at_central_region.limit(quantity).include_docs.rows.each do |row| 
              
                row["doc"]["site_code"] = code
                
                npids << row["doc"]
                
              end
            
              result = RestClient.post("http://#{CONFIG["username"]}:#{CONFIG["password"]}@#{CONFIG["host"]}:#{CONFIG["port"]}/#{CONFIG["prefix"]}#{(CONFIG["suffix"].strip.length > 0 ? "_" + CONFIG["suffix"] : "")}/_bulk_docs", {"docs" => npids}.to_json, {:content_type => :json})
              
              puts result
              
              return true
                
            when "north"                    
              npids = []
              
              Npid.unassigned_at_northern_region.limit(quantity).include_docs.rows.each do |row| 
              
                row["doc"]["site_code"] = code
                
                npids << row["doc"]
                
              end
            
              result = RestClient.post("http://#{CONFIG["username"]}:#{CONFIG["password"]}@#{CONFIG["host"]}:#{CONFIG["port"]}/#{CONFIG["prefix"]}#{(CONFIG["suffix"].strip.length > 0 ? "_" + CONFIG["suffix"] : "")}/_bulk_docs", {"docs" => npids}.to_json, {:content_type => :json})
              
              puts result
              
              return true
                            
            when "south"                    
              npids = []
              
              Npid.unassigned_at_southern_region.limit(quantity).include_docs.rows.each do |row| 
              
                row["doc"]["site_code"] = code
                
                npids << row["doc"]
                
              end
            
              result = RestClient.post("http://#{CONFIG["username"]}:#{CONFIG["password"]}@#{CONFIG["host"]}:#{CONFIG["port"]}/#{CONFIG["prefix"]}#{(CONFIG["suffix"].strip.length > 0 ? "_" + CONFIG["suffix"] : "")}/_bulk_docs", {"docs" => npids}.to_json, {:content_type => :json})
              
              puts result
              
              return true
              
            end   
        end
      
      end
      
      return false
    end
   
=begin
  + add_site(
      site:String, site_code:String, region:String, threshold:Integer
    ):BOOLEAN
  
    Given a site name and a site code, add a unique site.
=end
    def self.add_site(site, site_code, region, threshold, batchsize = 100)
    
      raise "First argument cannot be blank" if site.to_s.strip.match(/^$/)
      
      raise "Second argument cannot be blank" if site_code.to_s.strip.match(/^$/)
    
      raise "Third argument cannot be blank" if region.to_s.strip.match(/^$/)
    
      raise "Fourth argument can only be a number" if !threshold.to_s.strip.match(/^\d+$/)
    
      result = Site.create(name: site, site_code: site_code, region: region, threshold: threshold, batch_size: batchsize) # rescue nil
    
      return !result.nil?
    
    end
    
=begin
  + get_unassigned_npids():Array(JSON)
  
    A list of all npids that have not been assigned to a site.
=end
    def self.get_unassigned_npids()
      Npid.unassigned_to_site.collect{|e| e}
    end
    
=begin
  + get_all_sites():Array(JSON)
  
    A list of all sites captured.
=end
    def self.get_all_sites()
      Site.all.collect{|s| s}
    end
       
=begin
  + que_site(site:String, site_code:String, threshold:Integer, region:String):BOOLEAN
  
    Que a site for npids batch assignement.
=end
    def self.que_site(site, site_code, threshold, region)
      
      raise "First argument cannot be blank" if site.to_s.strip.match(/^$/)
      
      raise "Second argument cannot be blank" if site_code.to_s.strip.match(/^$/)
    
      raise "Third argument can only be an integer" if !threshold.to_s.strip.match(/^\d+$/)
    
      raise "Fourth argument cannot be blank" if region.to_s.strip.match(/^$/)
    
      result = RequestsQue.create(site_code: site_code, region: region, threshold: threshold)
      
      return !result.nil?
    end
        
=begin
  + check_site_thresholds():BOOLEAN
  
    Check all sites that have reached their thresholds for queueing.
=end
    def self.check_site_thresholds()
      sites = {} 
      
      Npid.untaken_at_region.include_docs.rows.each do |e| 
        
        site = e["doc"]
        
        if sites[site["site_code"]].nil? then 
          sites[site["site_code"]] = 1 
        else 
          sites[site["site_code"]] += 1 
        end
      end
      
      sites.each do |key, value|
        site = Site.find_by__id(key) rescue nil
        
        if !site.nil?
          # Update npid count at site for use later
          site.update_attributes(site_id_count: value.to_i)
          
          if value.to_i < site.threshold.to_i
            RequestsQue.create(site_code: key, region: site.region, threshold: site.threshold)
          end
        end
      end
      
      return true
    end
         
=begin
  + process_queued_sites():BOOLEAN
  
    Assign npids to all sites that have been queued.
=end
    def self.process_queued_sites()
      RequestsQue.pending.collect do |entry|
        site = Site.find_by__id(entry.site_code) rescue nil
        
        if !site.nil?
          if site.site_id_count < site.threshold
            Utils::Master.assign_npids_to_site(site.site_code, site.batch_size)            
          end
        end
        
        entry.update_attributes(request_processed: true)
      end
      
      return true
    end
      
=begin
  + assign_npids_to_region(
      region:String, quantity:Integer
    ):BOOLEAN
  
  Given a region and the number of ids to assign, this function aims at assigning 
  the given range of ids to the given region.
  
  An example would be given a region 'Central' which has to be assigned 10 ids,
  given the last assigned id was 20, the new ids to be assigned are from 21 to 31.
=end
    def self.assign_npids_to_region(region, quantity)
    
      @@npid_mutex = Mutex.new if @@npid_mutex.nil?
    
      @@npid_mutex.synchronize do
      
        raise "First argument cannot be blank" if region.to_s.strip.match(/^$/)
        
        raise "Second argument is supposed to be an integer" if !quantity.to_s.match(/^\d+$/)
      
        i = 0 
        
        npids = []
        
        Npid.unassigned_to_region.limit(quantity).include_docs.rows.each do |row| 
        
          row["doc"]["region"] = region
          
          npids << row["doc"]
          
        end
      
        result = RestClient.post("http://#{CONFIG["username"]}:#{CONFIG["password"]}@#{CONFIG["host"]}:#{CONFIG["port"]}/#{CONFIG["prefix"]}#{(CONFIG["suffix"].strip.length > 0 ? "_" + CONFIG["suffix"] : "")}/_bulk_docs", {"docs" => npids}.to_json, {:content_type => :json})
        
        puts result
        
        return true
      
      end
      
      return false
    end
         
=begin
  + check_if_npids_available():BOOLEAN
  
  
=end
    def self.check_if_region_npids_available(region)
      # result = Npid.assigned_at_this_region.count
      
      result = 0
      
      case region
        when "Centre"
          result = Npid.unassigned_at_central_region.count
        when "North"
          result = Npid.unassigned_at_northern_region.count
        when "South"
          result = Npid.unassigned_at_southern_region.count
      end
      
      return (result > 0)
    end
   
   
  end

end
