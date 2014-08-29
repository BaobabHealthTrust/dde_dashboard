class DashboardController < ActionController::Base 

  def person_map
    @connections = []
    @sites = []
     
    pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_sites'")
    
    Process.detach(pid1)
 
    pid2 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_connections'")
    
    Process.detach(pid2)
 
    if File.exists?("#{Rails.root}/tmp/statuses/sites.json")
    
      @sites = JSON.parse(File.open("#{Rails.root}/tmp/statuses/sites.json").read) rescue []
    
    end
     
    if File.exists?("#{Rails.root}/tmp/statuses/connections.json")
    
      @connections = JSON.parse(File.open("#{Rails.root}/tmp/statuses/connections.json").read) rescue []
    
    end
     
    # raise @sites.inspect
      
    render :layout => false
  end

  def npids_map
    @connections = []
    @sites = []
     
    pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_sites'")
    
    Process.detach(pid1)
 
    pid2 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_connections'")
    
    Process.detach(pid2)
 
    if File.exists?("#{Rails.root}/tmp/statuses/sites.json")
    
      @sites = JSON.parse(File.open("#{Rails.root}/tmp/statuses/sites.json").read) rescue []
    
    end
     
    if File.exists?("#{Rails.root}/tmp/statuses/connections.json")
    
      @connections = JSON.parse(File.open("#{Rails.root}/tmp/statuses/connections.json").read) rescue []
    
    end
     
    # raise @sites.inspect
      
    render :layout => false
  end

  def ajax_connections
  
    @sites = {sites: [], connections: []}
  
    pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_ajax_connections'")
    
    Process.detach(pid1)
 
    if File.exists?("#{Rails.root}/tmp/statuses/ajax_connections.json")
    
      @sites = JSON.parse(File.open("#{Rails.root}/tmp/statuses/ajax_connections.json").read) rescue []
    
    end
     
    render :json => @sites.to_json
  
  end

  def ajax_person_connections
  
    @sites = {sites: [], connections: []}
  
    pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_ajax_person_connections'")
    
    Process.detach(pid1)
 
    if File.exists?("#{Rails.root}/tmp/statuses/ajax_person_connections.json")
    
      @sites = JSON.parse(File.open("#{Rails.root}/tmp/statuses/ajax_person_connections.json").read) rescue []
    
    end
     
    render :json => @sites.to_json
  
  end

  def npids_distribution
    @connections = []
    @sites = [] 
     
    pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_sites'")
    
    Process.detach(pid1)
 
    pid2 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_connections'")
    
    Process.detach(pid2)
 
    if File.exists?("#{Rails.root}/tmp/statuses/sites.json")
    
      @sites = JSON.parse(File.open("#{Rails.root}/tmp/statuses/sites.json").read) rescue []
    
    end
     
    if File.exists?("#{Rails.root}/tmp/statuses/connections.json")
    
      @connections = JSON.parse(File.open("#{Rails.root}/tmp/statuses/connections.json").read) rescue []
    
    end
     
  end

  def ajax_npids_distribution
  
    @sites = []
  
    pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_ajax_npids_distribution'")
    
    Process.detach(pid1)
 
    if File.exists?("#{Rails.root}/tmp/statuses/ajax_npids_distribution.json")
    
      @sites = JSON.parse(File.open("#{Rails.root}/tmp/statuses/ajax_npids_distribution.json").read) rescue []
    
    end
     
    render :json => @sites.to_json
  
  end

  def burdens  
  end

  def ajax_burdens
  
    @sites = []
  
    pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_ajax_burdens'")
    
    Process.detach(pid1)
 
    if File.exists?("#{Rails.root}/tmp/statuses/ajax_burdens.json")
    
      @sites = JSON.parse(File.open("#{Rails.root}/tmp/statuses/ajax_burdens.json").read) rescue []
    
    end
     
    render :json => @sites.to_json
  
  end

  def ajax_movements
  
    @sites = {sites: [], movements: {}, total: 0, connections: []}
  
    pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/q_ajax_movements'")
    
    Process.detach(pid1)
 
    if File.exists?("#{Rails.root}/tmp/statuses/ajax_movements.json")
    
      @sites = JSON.parse(File.open("#{Rails.root}/tmp/statuses/ajax_movements.json").read) rescue []
    
    end
     
    render :json => @sites.to_json
  
  end

  def movements  
  end

  def dashboard
    
    @settings = YAML.load_file("#{Rails.root}/config/couchdb.yml")["networks"] rescue {}
    
  end

  def dual_display
    
    @settings = YAML.load_file("#{Rails.root}/config/couchdb.yml")["networks"] rescue {}
    
  end

end
