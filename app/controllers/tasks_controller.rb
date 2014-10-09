class TasksController < ActionController::Base

  def lock_files(name)

    settings = YAML.load_file("#{Rails.root}/config/couchdb.yml")[Rails.env] rescue {}

    if File.exists?("#{Rails.root}/tmp/statuses/#{name}.json")

      return "N/A" if (Time.now - File::stat("#{Rails.root}/tmp/statuses/#{name}.json").mtime) < ((settings["age"].to_i rescue 0) * 60)

    end

    return "Busy" if File.exists?("#{Rails.root}/tmp/statuses/.~#{name}.lock")

    file = File.open("#{Rails.root}/tmp/statuses/.~#{name}.lock", "w")

    file.write(Time.now)

    file.close

    return "OK"

  end

  def unlock_files(name, result)

    file = File.open("#{Rails.root}/tmp/statuses/.~#{name}.tmp", "w")

    file.write(result)

    file.close

    FileUtils.mv("#{Rails.root}/tmp/statuses/.~#{name}.tmp", "#{Rails.root}/tmp/statuses/#{name}.json") if File.exists?("#{Rails.root}/tmp/statuses/.~#{name}.tmp")

    FileUtils.rm("#{Rails.root}/tmp/statuses/.~#{name}.lock")

  end

  def query_sites

    lock = lock_files("sites")

    # render :text => lock and return

    case lock
      when "N/A"
        render :text => lock and return
      when "Busy"
        render :text => lock and return
    end

    @sites = []

    Site.list.rows.each do |source|

      row = source.value

      site = {
          site_code: row["site_code"],
          region: row["region"],
          x: row["x"],
          y: row["y"],
          name: row["name"],
          type: row["site_type"],
          ip_address: row["ip_address"]
      }

      @sites << site
    end

    unlock_files("sites", @sites.to_json)

    render :json => @sites.to_json

  end

  def query_connections

    lock = lock_files("connections")

    case lock
      when "N/A"
        render :text => lock and return
      when "Busy"
        render :text => lock and return
    end

    @connections = []

    Connection.all.rows.each do |row|
      src = row["key"].split("-") rescue []

      if src.length > 1

        source = Site.find_by__id(src[0]) rescue nil
        target = Site.find_by__id(src[1]) rescue nil

        if !source.nil? and !target.nil?
          site = {
              source: {
              site_code: source.site_code,
              region: source.region,
              x: source.x,
              y: source.y,
              name: source.name,
              type: source.site_type,
              ip_address: source.ip_address
          },
              target: {
              site_code: target.site_code,
              region: target.region,
              x: target.x,
              y: target.y,
              name: target.name,
              type: target.site_type,
              ip_address: target.ip_address
          },
              label: (row["key"] rescue nil),
              data: 0
          }

          @connections << site
        end
      end
    end

    unlock_files("connections", @connections.to_json)

    render :json => @connections.to_json

  end

  def query_ajax_connections

    lock = lock_files("ajax_connections")

    # render :text => lock and return

    case lock
      when "N/A"
        render :text => lock and return
      when "Busy"
        render :text => lock and return
    end

    @sites = {sites: [], connections: []}

    Connection.all.rows.each do |row|
      src = row["key"].split("-") rescue []

      if src.length > 1

        source = Site.find_by__id(src[0]) rescue nil
        target = Site.find_by__id(src[1]) rescue nil

        if !source.nil? and !target.nil?

          # Start getting connections even from remote servers

          result = JSON.parse(RestClient.get("http://#{source["username"]}:#{source["password"]}@#{source["ip_address"]}:5984/_active_tasks")) rescue []

          connections = {}

          result.each do |conn|

            src = conn["source"].strip.match(/(http\:\/\/(.+)\:\d+\/)?([^\/]+)/) # rescue nil

            tgt = conn["target"].strip.match(/(http\:\/\/(.+)\:\d+\/)?([^\/]+)/) # rescue nil

            next if src.nil? or tgt.nil?

            next if src[3].nil? or tgt[3].nil?

            next if (src[3].strip.downcase != source["site_db2"].strip.downcase) or (tgt[3].strip.downcase != target["site_db2"].strip.downcase)

            connections[[
                            (!src[2].nil? ? src[2] : "127.0.0.1"),
                            src[3],
                            (!tgt[2].nil? ? tgt[2] : "127.0.0.1"),
                            tgt[3]
                        ]] = {
                continuous: conn["continuous"],
                doc_write_failures: conn["doc_write_failures"],
                docs_read: conn["docs_read"],
                docs_written: conn["docs_written"],
                replication_id: conn["replication_id"],
                started_on: conn["started_on"],
                updated_on: conn["updated_on"],
                missing_revisions_found: conn["missing_revisions_found"],
                progress: conn["progress"],
                revisions_checked: conn["revisions_checked"],
                source_seq: conn["source_seq"],
                checkpointed_source_seq: conn["checkpointed_source_seq"],
                pid: conn["pid"]
            }

          end

          # Repeat for a connections on the target in case the source does no show connections

          result = []

          result = JSON.parse(RestClient.get("http://#{target["username"]}:#{target["password"]}@#{target["ip_address"]}:5984/_active_tasks")) rescue []

          result.each do |conn|

            src = conn["source"].strip.match(/(http\:\/\/(.+)\:\d+\/)?([^\/]+)/) # rescue nil

            tgt = conn["target"].strip.match(/(http\:\/\/(.+)\:\d+\/)?([^\/]+)/) # rescue nil

            next if src.nil? or tgt.nil?

            next if src[3].nil? or tgt[3].nil?

            next if (src[3].strip.downcase != source["site_db2"].strip.downcase) or (tgt[3].strip.downcase != target["site_db2"].strip.downcase)

            connections[[
                            (!src[2].nil? ? src[2] : "127.0.0.1"),
                            src[3],
                            (!tgt[2].nil? ? tgt[2] : "127.0.0.1"),
                            tgt[3]
                        ]] = {
                continuous: conn["continuous"],
                doc_write_failures: conn["doc_write_failures"],
                docs_read: conn["docs_read"],
                docs_written: conn["docs_written"],
                replication_id: conn["replication_id"],
                started_on: conn["started_on"],
                updated_on: conn["updated_on"],
                missing_revisions_found: conn["missing_revisions_found"],
                progress: conn["progress"],
                revisions_checked: conn["revisions_checked"],
                source_seq: conn["source_seq"],
                checkpointed_source_seq: conn["checkpointed_source_seq"],
                pid: conn["pid"]
            }

          end

          # raise connections.to_json

          # End connections retrieval

          site = {
              source: {
              sitecode: source.site_code,
              region: source.region,
              x: source.x,
              y: source.y,
              name: source.name,
              type: source.site_type,
              ip_address: source.ip_address
          },
              target: {
              sitecode: target.site_code,
              region: target.region,
              x: target.x,
              y: target.y,
              name: target.name,
              type: target.site_type,
              ip_address: target.ip_address
          },
              label: (row["key"] rescue nil)
          }

          site[:status] = {}

          if !connections[[source.ip_address, source.site_db1, target.ip_address, target.site_db1]].blank?

            site[:status][:person] = connections[[source.ip_address, source.site_db1, target.ip_address, target.site_db1]]

          else

            # if !CONFIG["master-master"].nil? and CONFIG["master-master"].to_s.downcase == "true"

            pid1 = spawn("curl -H 'Content-Type: application/json' -X POST -d '#{{
                source: "http://#{source.ip_address}:5984/#{source.site_db1}",
                target: "http://#{target.ip_address}:5984/#{target.site_db1}",
                connection_timeout: 60000,
                retries_per_request: 20,
                http_connections: 30,
                continuous: true
            }.to_json}' 'http://#{source.username}:#{source.password}@#{source.ip_address}:5984/_replicate'")

            Process.detach(pid1)

            # end

          end

          if !connections[[source.ip_address, source.site_db2, target.ip_address, target.site_db2]].blank?

            site[:status][:npid] = connections[[source.ip_address, source.site_db2, target.ip_address, target.site_db2]]

          else

            # if !CONFIG["master-master"].nil? and CONFIG["master-master"].to_s.downcase == "true"

            pid1 = spawn("curl -H 'Content-Type: application/json' -X POST -d '#{{
                source: "http://#{source.ip_address}:5984/#{source.site_db2}",
                target: "http://#{target.ip_address}:5984/#{target.site_db2}",
                connection_timeout: 60000,
                retries_per_request: 20,
                http_connections: 30,
                continuous: true,
            }.to_json}' 'http://#{source.username}:#{source.password}@#{source.ip_address}:5984/_replicate'")

            Process.detach(pid1)

            # end

          end

          @sites[:connections] << site
        end

      end
    end

    Site.list.rows.each do |source|

      row = source.value

      site = {
          site_code: row["site_code"],
          region: row["region"],
          x: row["x"],
          y: row["y"],
          name: row["name"],
          type: row["site_type"],
          ip_address: row["ip_address"]
      }

      @sites[:sites] << site
    end

    unlock_files("ajax_connections", @sites.to_json)

    render :json => @sites.to_json

  end

  def query_ajax_person_connections

    lock = lock_files("ajax_person_connections")

    # render :text => lock and return

    case lock
      when "N/A"
        render :text => lock and return
      when "Busy"
        render :text => lock and return
    end

    @sites = {sites: [], connections: []}

    Connection.all.rows.each do |row|
      src = row["key"].split("-") rescue []

      if src.length > 1

        source = Site.find_by__id(src[0]) rescue nil
        target = Site.find_by__id(src[1]) rescue nil

        if !source.nil? and !target.nil?

          # Start getting connections even from remote servers

          result = JSON.parse(RestClient.get("http://#{source["username"]}:#{source["password"]}@#{source["ip_address"]}:5984/_active_tasks")) rescue []

          connections = {}

          result.each do |conn|

            src = conn["source"].strip.match(/(http\:\/\/(.+)\:\d+\/)?([^\/]+)/) # rescue nil

            tgt = conn["target"].strip.match(/(http\:\/\/(.+)\:\d+\/)?([^\/]+)/) # rescue nil

            next if src.nil? or tgt.nil?

            next if src[3].nil? or tgt[3].nil?

            next if (src[3].strip.downcase != source["site_db1"].strip.downcase) or (tgt[3].strip.downcase != target["site_db1"].strip.downcase)

            connections[[
                            (!src[2].nil? ? src[2] : "127.0.0.1"),
                            src[3],
                            (!tgt[2].nil? ? tgt[2] : "127.0.0.1"),
                            tgt[3]
                        ]] = {
                continuous: conn["continuous"],
                doc_write_failures: conn["doc_write_failures"],
                docs_read: conn["docs_read"],
                docs_written: conn["docs_written"],
                replication_id: conn["replication_id"],
                started_on: conn["started_on"],
                updated_on: conn["updated_on"],
                missing_revisions_found: conn["missing_revisions_found"],
                progress: conn["progress"],
                revisions_checked: conn["revisions_checked"],
                source_seq: conn["source_seq"],
                checkpointed_source_seq: conn["checkpointed_source_seq"],
                pid: conn["pid"]
            }

          end

          # Repeat for a connections on the target in case the source does no show connections

          result = []

          result = JSON.parse(RestClient.get("http://#{target["username"]}:#{target["password"]}@#{target["ip_address"]}:5984/_active_tasks")) rescue []

          result.each do |conn|

            src = conn["source"].strip.match(/(http\:\/\/(.+)\:\d+\/)?([^\/]+)/) # rescue nil

            tgt = conn["target"].strip.match(/(http\:\/\/(.+)\:\d+\/)?([^\/]+)/) # rescue nil

            next if src.nil? or tgt.nil?

            next if src[3].nil? or tgt[3].nil?

            next if (src[3].strip.downcase != source["site_db1"].strip.downcase) or (tgt[3].strip.downcase != target["site_db1"].strip.downcase)

            connections[[
                            (!src[2].nil? ? src[2] : "127.0.0.1"),
                            src[3],
                            (!tgt[2].nil? ? tgt[2] : "127.0.0.1"),
                            tgt[3]
                        ]] = {
                continuous: conn["continuous"],
                doc_write_failures: conn["doc_write_failures"],
                docs_read: conn["docs_read"],
                docs_written: conn["docs_written"],
                replication_id: conn["replication_id"],
                started_on: conn["started_on"],
                updated_on: conn["updated_on"],
                missing_revisions_found: conn["missing_revisions_found"],
                progress: conn["progress"],
                revisions_checked: conn["revisions_checked"],
                source_seq: conn["source_seq"],
                checkpointed_source_seq: conn["checkpointed_source_seq"],
                pid: conn["pid"]
            }

          end

          # End connections retrieval

          site = {
              source: {
              sitecode: source.site_code,
              region: source.region,
              x: source.x,
              y: source.y,
              name: source.name,
              type: source.site_type,
              ip_address: source.ip_address
          },
              target: {
              sitecode: target.site_code,
              region: target.region,
              x: target.x,
              y: target.y,
              name: target.name,
              type: target.site_type,
              ip_address: target.ip_address
          },
              label: (row["key"] rescue nil)
          }

          site[:status] = {}

          if !connections[[source.ip_address, source.site_db1, target.ip_address, target.site_db1]].blank?

            site[:status][:person] = connections[[source.ip_address, source.site_db1, target.ip_address, target.site_db1]]

          else

            # if !CONFIG["master-master"].nil? and CONFIG["master-master"].to_s.downcase == "true"

            pid1 = spawn("curl -H 'Content-Type: application/json' -X POST -d '#{{
                source: "http://#{source.ip_address}:5984/#{source.site_db1}",
                target: "http://#{target.ip_address}:5984/#{target.site_db1}",
                connection_timeout: 60000,
                retries_per_request: 20,
                http_connections: 30,
                continuous: true
            }.to_json}' 'http://#{source.username}:#{source.password}@#{source.ip_address}:5984/_replicate'")

            Process.detach(pid1)

            # end

          end

          if !connections[[source.ip_address, source.site_db2, target.ip_address, target.site_db2]].blank?

            site[:status][:npid] = connections[[source.ip_address, source.site_db2, target.ip_address, target.site_db2]]

          else

            # if !CONFIG["master-master"].nil? and CONFIG["master-master"].to_s.downcase == "true"

            pid1 = spawn("curl -H 'Content-Type: application/json' -X POST -d '#{{
                source: "http://#{source.ip_address}:5984/#{source.site_db2}",
                target: "http://#{target.ip_address}:5984/#{target.site_db2}",
                connection_timeout: 60000,
                retries_per_request: 20,
                http_connections: 30,
                continuous: true,
            }.to_json}' 'http://#{source.username}:#{source.password}@#{source.ip_address}:5984/_replicate'")

            Process.detach(pid1)

            # end

          end

          @sites[:connections] << site
        end

      end
    end

    Site.list.rows.each do |source|

      row = source.value

      site = {
          site_code: row["site_code"],
          region: row["region"],
          x: row["x"],
          y: row["y"],
          name: row["name"],
          type: row["site_type"],
          ip_address: row["ip_address"]
      }

      @sites[:sites] << site
    end

    unlock_files("ajax_person_connections", @sites.to_json)

    render :json => @sites.to_json

  end

  def query_ajax_npids_distribution

    lock = lock_files("ajax_npids_distribution")

    # render :text => lock and return

    case lock
      when "N/A"
        render :text => lock and return
      when "Busy"
        render :text => lock and return
    end

    @sites = []

    if !CONFIG["master-master"].nil? and CONFIG["master-master"].to_s.downcase == "true"

      pid1 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/check_thresholds'")

      Process.detach(pid1)

      pid2 = spawn("curl 'http://#{request.env["HTTP_HOST"]}/process_queued_sites'")

      Process.detach(pid2)

    end

    Site.list.rows.each do |source|

      row = source.value

      available = Npid.untaken_at_region.keys([row["site_code"]]).rows.length

      proportion = (available / (row["threshold"].to_f + row["batch_size"].to_f)) # rescue 0

      site = {
          site_code: row["site_code"],
          region: row["region"],
          x: row["x"],
          y: row["y"],
          name: row["name"],
          type: row["site_type"],
          ip_address: row["ip_address"],
          available: available,
          threshold: row["threshold"],
          batch_size: row["batch_size"],
          proportion: proportion
      }

      @sites << site
    end

    unlock_files("ajax_npids_distribution", @sites.to_json)

    render :json => @sites.to_json

  end

  def query_ajax_burdens

    lock = lock_files("ajax_burdens")

    # render :text => lock and return

    case lock
      when "N/A"
        render :text => lock and return
      when "Busy"
        render :text => lock and return
    end

    @sites = []

    total = Footprint.by_site.rows.length

    Site.list.rows.each do |source|

      row = source.value

      seen = Footprint.by_site.keys([row["site_code"]]).rows.length

      proportion = (seen / total.to_f) # rescue 0

      site = {
          site_code: row["site_code"],
          region: row["region"],
          x: row["x"],
          y: row["y"],
          name: row["name"],
          type: row["site_type"],
          ip_address: row["ip_address"],
          seen: seen,
          threshold: row["threshold"],
          batch_size: row["batch_size"],
          proportion: proportion
      }

      @sites << site
    end

    unlock_files("ajax_burdens", @sites.to_json)

    render :json => @sites.to_json

  end

  def query_ajax_movements

    lock = lock_files("ajax_movements")

    case lock
      when "N/A"
        render :text => lock and return
      when "Busy"
        render :text => lock and return
    end

    @sites = {sites: [], movements: {}, total: 0, connections: []}

    Footprint.by_migration.keys.each do |key|

      if @sites[:movements][key].blank?

        @sites[:movements][key] = 1

      else

        @sites[:movements][key] += 1

      end

      @sites[:total] += 1

    end

    @sites[:movements].each do |key, value|

      source = Site.find_by__id(key[0]) rescue nil
      target = Site.find_by__id(key[1]) rescue nil

      if !source.nil? and !target.nil?
        site = {
            source: {
            sitecode: source.site_code,
            region: source.region,
            x: source.x,
            y: source.y,
            name: source.name,
            type: source.site_type,
            ip_address: source.ip_address
        },
            target: {
            sitecode: target.site_code,
            region: target.region,
            x: target.x,
            y: target.y,
            name: target.name,
            type: target.site_type,
            ip_address: target.ip_address
        },
            label: key.join("-") + " Migration",
            magnitude: value
        }

        @sites[:connections] << site
      end

    end

    Site.list.rows.each do |source|

      row = source.value

      site = {
          site_code: row["site_code"],
          region: row["region"],
          x: row["x"],
          y: row["y"],
          name: row["name"],
          type: row["site_type"],
          ip_address: row["ip_address"]
      }

      @sites[:sites] << site
    end

    unlock_files("ajax_movements", @sites.to_json)

    render :json => @sites.to_json

  end

end
