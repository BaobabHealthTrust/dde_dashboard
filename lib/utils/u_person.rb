module Utils

  class UPerson
    
    @@page_size = CONFIG["pagesize"] rescue 10
    
=begin
  + process_person_data(JSON):Array(JSON)
  
  This method returns an array of results to accommodate to cases where further 
  verification is required of person to work with before processing.
  
  The method is expected to be the main entry for all data processing for patients.
  These scenarios are:
    1. NEW PATIENT CREATION where all available fields are filled in except for 
        the national_id field which indicates it's a new record. However, before
        creating, allow for verification first if very close matches for similar 
        records exist to avoid unnecessary person demographics repetition.
        
    2. EXISTING PATIENT ADDITION where all available fields including the national_id
        are filled in. Before updating is done, disambiguation and confirmation 
        has to be done to avoid overwriting wrong records and unnecessary 
        data repetitions.
        
    3. NATIONAL IDENTIFIER DISAMBIGUATION where cases of multiple occurences of
        specific identifiers are presented for confirmation if the required case
        matches any of those presented or completely new instances have to be created
=end
    def self.process_person_data(json, page=1, pagesize=@@page_size)
      raise "Argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil).nil?
        
      result = []
              
      person = JSON.parse(json)
      
      identifier = (person["national_id"] || person["_id"]) rescue nil
      
      if !identifier.blank? # and (self.is_valid_v4_npid(identifier) or self.is_valid_temporary_id(identifier))
        
        result = self.search_by_npid(json, page)
        
      else
              
        if !person["names"]["given_name"].blank? and !person["names"]["family_name"].blank? and !person["gender"].blank?      
          result = self.search_for_person_by_params(
            person["names"]["given_name"],
            person["names"]["family_name"],
            person["gender"],
            person["date_of_birth"],
            (person["addresses"]["home_t_a"] rescue nil),
            (person["addresses"]["home_district"] rescue nil),
            page,
            pagesize
          )
        end   
      
      end
              
      return result
    end
  
=begin
  + confirmed_person_to_create_or_update_or_select(JSON, action="update"):JSON
  
  This is an internal method expected to be called after a trigger from 
  process_person_data for patient confirmation has yielded it's results.
  
  This method handles 3 main types of transactions after confirmation of person
  record is done which are:
    1. UPDATE selected person record (default)
    2. CREATE selected person record
    3. SELECT selected person record for further processing
    4. REPLACE TEMPORARY NPIDs when new NPIDS are available
  
  Footprint tracking to be done from here as well
=end
    def self.confirmed_person_to_create_or_update_or_select(json, action="update")

      raise "Argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil).nil?
    
      result = "{}"
      
      case action.downcase
      when "create"
        
        # Try to get a new identifier
        outcome = Utils::Proxy.assign_npid_to_person(json)
          
        if (!JSON.parse(outcome).blank? rescue false)
          
          output = self.create_person(outcome) rescue false
            
          if output
            result = outcome
          end
          
        else
          
          # NPIDs not available, get a temporary identifier
          outcome = Utils::Proxy.assign_temporary_npid(json)
            
          if (!JSON.parse(outcome).blank? rescue false)
          
            output = self.create_person(outcome) # rescue false
              
            if output
              result = outcome
            end
              
          end
            
        end
          
      when "update"
        output = self.update_person(json)
          
        result = json if output
      else
        
        person = JSON.parse(json) rescue nil
          
        # If the presented NPID is not a valid version 4, try to recreate another one
        if !person.nil? and !self.is_valid_v4_npid((person["national_id"] || person["_id"]))
            
          result = self.update_npid(json)
            
        else
            
          result = json
          
        end
        
      end
    
      obj = JSON.parse(result) # rescue {}
      
      Utils::FootprintUtil.log_application_and_site((obj["national_id"] || obj["_id"]), obj["application"], obj["site_code"]) rescue nil if !obj["application"].blank? and !obj["site_code"].blank?
    
      return result      
    end    

=begin
  + search_by_npid(npid:String):Array(JSON)
  
  Ideally, this method is supposed to only return 1 result. However, a search could
  in some cases be done by other identifiers which are also expected to pass
  through this method. Such types of identifiers could be:
  - Temporary identifiers
  - Legacy identifiers or
  - Application specific identifiers
=end
    def self.search_by_npid(json, page=1)
      raise "Argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil).nil?
      
      result = []
             
      param = (JSON.parse(json)["national_id"] || JSON.parse(json)["_id"]) # rescue nil
         
      if !param.blank?
      
        person = Person.find_by__id(param)
        
        if !person.nil?
          
          result << person.to_json
            
        end
          
        (Person.search_by_all_identifiers.keys([param]).page(page).per(@@page_size).rows).each do |row|
        
          person = Person.find_by__id(row["id"]) # rescue nil
          
          if !person.nil?
          
            result << person.to_json
            
          end
        
        end
        
      end
           
      return result.uniq
    end

    # All methods from here onwards are not supposed to be called from outside the module class
    
    private
=begin
  + person_has_v4_id(JSON):BOOLEAN
  
  
=end
    def self.person_has_v4_id(json)
      raise "Argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil).nil?  
        
      person = JSON.parse(json)
      
      npid = (person["national_id"] || person["_id"]) rescue nil
      
      if !npid.nil?
        return self.is_valid_v4_npid(npid)
      end
        
      return false
    end

=begin
  + search_for_person_by_params(
      first_name:String,
      last_name:String,
      gender:String,
      date_of_birth:String(OPTIONAL),
      home_t_a:String(OPTIONAL),
      home_district:String(OPTIONAL)
    ):JSON
  
  
=end
    def self.search_for_person_by_params(first_name, last_name, gender, date_of_birth=nil, home_t_a=nil, home_district=nil, page=1, pagesize=@@page_size)

      raise "First argument cannot be blank" unless !first_name.blank?
      raise "Second argument cannot be blank" unless !last_name.blank?
      raise "Third argument cannot be blank" unless !gender.blank?

      result = []
       
      fname_code = first_name.soundex
      lname_code = last_name.soundex
       
      yr = ((date_of_birth.to_date.year rescue nil) || Date.today.year)
          
      if !date_of_birth.nil? and !home_t_a.nil? and !home_district.nil?
      
        params = []
        
        ((yr - 5)..(yr + 5)).each do |y|
          
          params << [fname_code, lname_code, gender, y, home_t_a, home_district]
          
        end
      
        (Person.advanced_search.keys(params).page(page).per(pagesize).rows).each do |row|
        
          person = Person.find_by__id(row["id"]) # rescue nil
          
          if !person.nil?
          
            result << person.to_json
            
          end
        
        end
        
      elsif !date_of_birth.nil? and !home_t_a.nil? and home_district.nil?
      
        params = []
        
        ((yr - 5)..(yr + 5)).each do |y|
          
          params << [fname_code, lname_code, gender, y, home_t_a]
          
        end
      
        (Person.search_with_dob_home_ta.keys(params).page(page).per(pagesize).rows).each do |row|
        
          person = Person.find_by__id(row["id"]) # rescue nil
          
          if !person.nil?
          
            result << person.to_json
            
          end
        
        end
      
      elsif !date_of_birth.nil? and home_t_a.nil? and !home_district.nil?
      
        params = []
        
        ((yr - 5)..(yr + 5)).each do |y|
          
          params << [fname_code, lname_code, gender, y, home_district]
          
        end
      
        (Person.search_with_dob_home_district.keys(params).page(page).per(pagesize).rows).each do |row|
        
          person = Person.find_by__id(row["id"]) # rescue nil
          
          if !person.nil?
          
            result << person.to_json
            
          end
        
        end
        
      elsif !date_of_birth.nil? and home_t_a.nil? and home_district.nil?
      
        params = []
        
        ((yr - 5)..(yr + 5)).each do |y|
          
          params << [fname_code, lname_code, gender, y]
          
        end
      
        (Person.search_with_dob.keys(params).page(page).per(pagesize).rows).each do |row|
        
          person = Person.find_by__id(row["id"]) # rescue nil
          
          if !person.nil?
          
            result << person.to_json
            
          end
        
        end
        
      elsif !date_of_birth.nil? and !home_t_a.nil? and home_district.nil?
      
        params = []
        
        ((yr - 5)..(yr + 5)).each do |y|
          
          params << [fname_code, lname_code, gender, y, home_t_a]
          
        end
      
        (Person.search_with_home_district.keys(params).page(page).per(pagesize).rows).each do |row|
        
          person = Person.find_by__id(row["id"]) # rescue nil
          
          if !person.nil?
          
            result << person.to_json
            
          end
        
        end
        
      elsif date_of_birth.nil? and !home_t_a.nil? and home_district.nil?
      
        (Person.search_with_home_ta.keys([[fname_code, lname_code, gender, home_t_a]]).page(page).per(pagesize).rows).each do |row|
        
          person = Person.find_by__id(row["id"]) # rescue nil
          
          if !person.nil?
          
            result << person.to_json
            
          end
        
        end
        
      else
      
        (Person.search.keys([[fname_code, lname_code, gender]]).page(page).per(pagesize).rows).each do |row|
        
          person = Person.find_by__id(row["id"]) # rescue nil
          
          if !person.nil?
          
            result << person.to_json
            
          end
        
        end
      
      end
              
      return result
    end
    
=begin
  + create_person(JSON):BOOLEAN
  
  
=end
    def self.create_person(json)
      raise "Argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil).nil?
      
      result = false
      
      person = JSON.parse(json)
      
      person[:patient_assigned] = true
      
      person["person_attributes"] = person["attributes"] if person["person_attributes"].blank? and
       person["attributes"].present?
      
      outcome = Person.create(person) rescue nil
     
      result = !outcome.blank?
      
      return result
    end
          
=begin
  + update_person(JSON):BOOLEAN
  
  
=end
    def self.update_person(json)
      raise "Argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil).nil?
      
      result = false
      
      input = JSON.parse(json)
      
      person = Person.find_by__id((input["national_id"] || input["_id"])) # rescue nil
      
      result = person.update_attributes(input) rescue false
      
      identifiers = []
      
      if (input["patient"]["identifiers"] rescue "").class.to_s.downcase == "hash"
      
        tmp = input["patient"]["identifiers"]
        
        input["patient"]["identifiers"] = []
        
        tmp.each do |key, value|
          
          input["patient"]["identifiers"] << {key => value}
          
        end
      
      end
      
      (input["patient"]["identifiers"] rescue []).each do |id|
      
        identifiers << {id.keys[0] => id[id.keys[0]]}
      
      end
      
      result = person.update_attributes(patient: {identifiers: identifiers})
      
      return result
    end
 
=begin
  + get_person(npid:String):JSON
  
  
=end
    def self.get_person(npid)
      raise "Argument expected to be a valid version 4 ID" if !self.is_valid_v4_npid(npid)
      
      result = {}
      
      outcome = Person.find_by__id(npid) rescue nil
      
      if !outcome.blank?
        result = outcome
      end
      
      return result.to_json
    end
    
    def self.is_valid_temporary_id(identifier)
      if identifier.match(/^[A-Z]{3}[A-Z0-9]{11}/)
        return true
      else
        return false
      end
    end
    
    def self.is_valid_v4_npid(identifier)
    
      return false if identifier.length > 7
      
      num = self.to_decimal(identifier)
      
      if self.valid?(num)
        return true
      else
        return false
      end
    end
    
    # @author: Mike Mckay
    # Calculate a check digit using Luhn's Algorithm as implemented in BART
    # http://en.wikipedia.org/wiki/Luhn_algorithm
    # PatientIdentifier.calculate_checkdigit
    def self.check_digit(number)
      # This is Luhn's algorithm for checksums
      # http://en.wikipedia.org/wiki/Luhn_algorithm
      # Same algorithm used by PIH (except they allow characters)
      number = number.to_s
      number = number.split(//).collect { |digit| digit.to_i }
      parity = number.length % 2

      sum = 0
      number.each_with_index do |digit,index|
        digit = digit * 2 if index%2==parity
        digit = digit - 9 if digit > 9
        sum = sum + digit
      end

      checkdigit = 0
      checkdigit = checkdigit +1 while ((sum+(checkdigit))%10)!=0
      checkdigit
    end
    
    # Convert given <tt>num</tt> in from the specified <tt>from_base</tt> to
    # decimal (base 10)
    def self.to_decimal(num, from_base=30)
      @@separator = "-"
      @@reverse_map = {'0' => 0,'1' => 1,'2' => 2,'3' => 3,'4' => 4,'5' => 5,
        '6' => 6,'7' => 7,'8' => 8,'9' => 9,
        'A' => 10,'C' => 11,'D' => 12,'E' => 13,'F' => 14,'G' => 15,
        'H' => 16,'J' => 17,'K' => 18,'L' => 19,'M' => 20,'N' => 21,
        'P' => 22,'R' => 23,'T' => 24,'U' => 25,'V' => 26,'W' => 27,
        'X' => 28,'Y' => 29}
      
      decimal = 0
      num.to_s.gsub(@@separator, '').split('').reverse.each_with_index do |n, i|
        decimal += (@@reverse_map[n] * (from_base ** i) rescue 0)
      end
      decimal
    end

    # Checks if <tt>num<tt> has a correct check digit
    def self.valid?(num)
      core_id = num / 10
      check_digit = num % 10 # last digit

      check_digit == self.check_digit(core_id)
    end
    
=begin
    - update_npid(JSON):JSON
    
    Given a JSON Object with an old NPID, recreate a record with a version 4 ID
    and destroy the initial one while maintaining the current identifier as part
    of other identifiers
=end    
    def self.update_npid(json)
    
      obj = JSON.parse(json)
      
      person = Person.find_by__id((obj["national_id"] || obj["_id"])) rescue nil
      
      if !person.nil? and Utils::Proxy.check_if_npids_available()
        
        outcome = Utils::Proxy.assign_npid_to_person(json) # rescue "{}"
          
        if (!JSON.parse(outcome).blank? rescue false)
          
          result = JSON.parse(outcome)
          
          result["patient"]["identifiers"] = result["patient"]["identifiers"].uniq
          
          result["print_barcode"] = true
          
          result.delete("_id") rescue nil
          
          result.delete("_rev") rescue nil
          
          result.delete("type") rescue nil
          
          result["person_attributes"] = [] if result["person_attributes"].blank?
          
          output = Person.create(result) # rescue false
          
          # We've recreated the record with a new npid so we can delete the old one
          if output
            person.destroy
          end         
          
          return result.to_json
          
        end
        
      end
      
      return json
    
    end
    
=begin
    + compare_people(person_a:JSON, person_b:JSON):BOOLEAN
=end

    def self.compare_people(personA,personB )

      single_attributes = ['birthdate', 'gender']
      addresses = ['current_residence','current_village','current_ta','current_district','home_village','home_ta','home_district',]
      attributes = ['citizenship', 'race', 'occupation','home_phone_number', 'cell_phone_number', 'office_phone_number']

      single_attributes.each do |metric|
        if personA[metric] != personB[metric]
          return false
        end
      end

      attributes.each do |metric|
        if personA['person_attributes'][metric] != personB['person_attributes'][metric]
          return false
        end
      end

      addresses.each do |metric|
        if self['addresses'][metric] != person['addresses'][metric]
          return false
        end
      end

      return true

    end
    
    def self.log_footprint(json)
      
      obj = JSON.parse(json) # rescue {}
      
      result = Utils::FootprintUtil.log_application_and_site((obj["national_id"] || obj["_id"]), obj["application"], obj["site_code"]) rescue nil if !obj["application"].blank? and !obj["site_code"].blank?
    
      return !result.blank?
    
    end
    
  end
end
