confs = YAML.load_file(Rails.root.join('config', 'couchdb.yml'))[Rails.env]

if !confs["mode"].nil? && Rails.env.downcase != "test" && false
  logger = Logger.new("#{Rails.root}/log/background_processes_thresholds.log")

  logger.info("Running in '#{(!confs["mode"].nil? ? confs["mode"] : "undefined")}' mode")

  if confs["mode"].to_s.strip.downcase == "master"

    Thread.new do |t|
      
      while true
      
        # Wait for server to warm up
        sleep 1000
        
        logger.info("Checking thresholds")
        
        result = RestClient.get("http://localhost:#{confs["port"] rescue 3000}/check_thresholds") rescue "nothing"
        
        logger.info("Received #{result}")
        
        # Wait a bit in case other processes are being affected by this thread
        sleep 1000
        
        logger.info("Processing queues")
        
        result = RestClient.get("http://localhost:#{confs["port"] rescue 3000}/process_queued_sites") rescue "nothing"
        
        logger.info("Received #{result}")
        
      end

    end
  
  end

end
