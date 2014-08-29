module Utils

  class PersonUtil
  
=begin
  + process_person_data(JSON):JSON
  
  
=end
    def self.process_person_data(json)
    
      raise "First argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil).nil?
      js = JSON.parse(json)
      old_national_id = js["person"]["data"]["patient"]["identifiers"]["old_identification_number"] rescue nil

      if js["value"].blank? and js.length > 2 and js["action"] == "check_similarities"
        people = search_for_person_by_params(js["person"]["names"]["given_name"].soundex,
                                             js["person"]["names"]["family_name"].soundex ,
                                             js["person"]["gender"],"",js["person"]["addresses"]["county_district"],
                                             js["person"]["addresses"]["address2"])
      elsif js["value"].blank? and js.length > 2 and old_national_id.blank? and js["action"] != "create"
        people = search_for_person_by_params(js["given_name"].soundex,js["family_name"].soundex ,js["gender"])
      elsif js["value"] and js.length <=2
        person = search_by_npid(js)
      elsif js["value"] and js.length > 2 and js["action"] == "find"
        person = search_by_npid(js)
      elsif js["value"].blank? and !old_national_id.blank? and js["action"] != "create"
        person = create_person(json)
      elsif js["value"].blank? and old_national_id.blank? and js.length > 2 and js["action"] == "create"
        person = create_person(json)
      else
        return nil
      end
  end

=begin
  + search_by_npid(npid:String):Array(JSON)
  
  
=end
    def self.search_by_npid(json)
       npid = json["value"]
       person = self.get_person(npid)
       unless person.blank?
         person = convert_person(person)
       end
       return person   
    end

   def self.convert_person(person)
    person_hash = {:person => {:birthdate_estimated => person.birthdate_estimated}}
    birthdate = { :birthdate => person.birthdate}
    gender = {:gender => person.gender}
    given_name = {:given_name => person.names.given_name}
    family_name = {:family_name => person.names.family_name}
    data_hash = {:data => {:addresses => {:address1 => person.addresses.current_residence,
																					:address2 => person.addresses.current_village, 
																					:address1 => person.addresses.current_ta,
																					:city_village => person.addresses.current_district,
																					:state_province => person.addresses.home_village,
																					:county_district => person.addresses.home_ta,
																					:neighborhood_cell => person.addresses.home_district},
                           :attributes => {:home_phone_number => person.person_attributes.home_phone_number,
																						:cell_phone_number => person.person_attributes.cell_phone_number,
                                            :office_phone_number => person.person_attributes.office_phone_number,
																						:occupation => person.person_attributes.occupation,
																						:citizenship => person.person_attributes.citizenship,
																						:race => person.person_attributes.race
                                      }}} 

    person_hash[:person].merge! birthdate
    person_hash[:person].merge! gender
    person_hash[:person].merge! given_name
    person_hash[:person].merge! family_name
    person_hash[:person].merge! data_hash

    return person_hash 
    
  end

    private
=begin
  + person_has_v4_id(JSON):BOOLEAN
  
  
=end
    def self.person_has_v4_id(json)

       unless json["value"].blank?
            person = self.get_person(json["value"])
        person.blank? ? false : true
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
    def self.search_for_person_by_params(first_name,last_name ,gender, date_of_birth=nil, home_t_a=nil, home_district=nil)

      raise "First argument cannot be blank" unless !first_name.blank?
      raise "Second argument cannot be blank" unless !last_name.blank?
      raise "Third argument cannot be blank" unless !gender.blank?

      people = []
      if (date_of_birth.blank? && home_t_a.blank? && home_district.blank?)
        return Person.search.keys([[first_name.soundex,last_name.soundex ,gender]]).rows
      elsif (!date_of_birth.blank? && home_t_a.blank? && home_district.blank?)
        return Person.search_with_dob.keys([[first_name.soundex,last_name.soundex ,gender, date_of_birth]]).rows
      elsif (date_of_birth.blank? && home_t_a.blank? && !home_district.blank?)
        return Person.search_with_home_district.keys([[first_name.soundex,last_name.soundex ,gender,home_district]]).rows
      elsif (date_of_birth.blank? && !home_t_a.blank? && home_district.blank?)
        return Person.search_with_home_ta.keys([[first_name.soundex,last_name.soundex ,gender,home_t_a]]).rows
      elsif (date_of_birth.blank? && !home_t_a.blank? && !home_district.blank?)
        return Person.search_with_home_ta_district.keys([[first_name.soundex,last_name.soundex ,gender,home_t_a,home_district]]).rows
      elsif (!date_of_birth.blank? && !home_t_a.blank? && home_district.blank?)
        return Person.search_with_dob_home_ta.keys([[first_name.soundex,last_name.soundex ,gender,date_of_birth,home_t_a]]).rows
      elsif (!date_of_birth.blank? && home_t_a.blank? && !home_district.blank?)
        return Person.search_with_dob_home_district.keys([[first_name.soundex,last_name.soundex ,gender,date_of_birth, home_district]]).rows
      elsif (!date_of_birth.blank? && !home_t_a.blank? && !home_district.blank?)
        return Person.advanced_search.keys([[first_name.soundex,last_name.soundex ,gender,date_of_birth, home_t_a, home_district]]).rows
      end
      return people
    end
  
=begin
  + confirm_person_to_update(JSON):Array(JSON)
  
  
=end
    def self.confirm_person_to_update(json)

      raise "Argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil).nil?

      js = JSON.parse(json) rescue nil

      person = Person.get(js[:npid]) rescue nil
      results = []
      if !person.blank?
        if compare_people(person, js)
           results << js << person
        end
      end

      return results
    end
   
=begin
  + create_person(JSON):BOOLEAN
  
  
=end
    def self.create_person(json)

      raise "Argument can only be a JSON Object" if !json.match(/\{(.+)?\}/)
    
       js = Proxy.assign_npid_to_person(json)
       person_js = JSON.parse(js)
       
       if person_js.blank?
         person_js = Proxy.assign_temporary_npid(json)
         person = JSON(person_js)
       else
         person = person_js
       end
       
       unless person.blank?
		     legacy_national_id = person["person"]["data"]["patient"]["identifiers"]["old_identification_number"]
         national_id = person["national_id"]
		     national_id = person["identifiers"]["temporary_id"] if national_id.blank?
		     @person = Person.new(
		    				 :national_id => national_id,
								 :assigned_site =>  Site.current_code,
								 :patient_assigned => true,
								 :person_attributes => { :citizenship => person["person"]["data"]["attributes"]["citizenship"] || nil,
																				 :occupation => person["person"]["data"]["attributes"]["occupation"] || nil,
																				 :home_phone_number => person["person"]["data"]["attributes"]["home_phone_number"] || nil,
																				 :cell_phone_number => person["person"]["data"]["attributes"]["cell_phone_number"] || nil,
																				 :office_phone_number => person["person"]["data"]["attributes"]["office_phone_number"] || nil,
                                         :race => person["person"]["data"]["attributes"]["race"] || nil
												                },

									:gender => person["person"]["data"]["gender"],

									:names => { :given_name => person["person"]["data"]["names"]["given_name"],
								 					    :family_name => person["person"]["data"]["names"]["family_name"],
												    },

									:birthdate => person["person"]["data"]["birthdate"] || nil,
									:birthdate_estimated => person["person"]["data"]["birthdate_estimated"] || nil,

									:addresses => {:current_residence => person["person"]["data"]["addresses"]["city_village"] || nil,
														     :current_village => person["person"]["data"]["addresses"]["city_village"] || nil,
														     :current_ta => person["person"]["data"]["addresses"]["state_province"] || nil,
														     :current_district => person["person"]["data"]["addresses"]["state_province"] || nil,
														     :home_village => person["person"]["data"]["addresses"]["neighbourhood_cell"] || nil,
														     :home_ta => person["person"]["data"]["addresses"]["county_district"] || nil,
														     :home_district => person["person"]["data"]["addresses"]["address2"] || nil
		                            },
                 :old_identification_number => legacy_national_id
        )

        person = @person.save 
        return true
      else 
        return false
      end
   end
         
=begin
  + update_person(JSON):BOOLEAN
  
  
=end
    def self.update_person(json)

      raise "Argument can only be a JSON Object" unless !(JSON.parse(json) rescue nil ).nil?

      js = JSON.parse(json) rescue nil

      unless js.blank?
        person = Person.get(js["npid"])

        if person.blank?
          person = create_person(json)
          return person.blank?
        else

          has_new_id = person_has_v4_id(js)

          if !has_new_id
            if Proxy.check_if_npids_available()

              new_person = create_person(json)

              new_person["patient"] = { "identifiers" => {} } if person["patient"].blank?
              if new_person.national_id.first.upcase == "P"
                new_person["patient"]["identifiers"]["legacy_npid"] = person.national_id
              else
                new_person["patient"]["identifiers"]["temporary_npid"] = person.national_id
              end
              return person.destroy if new_person.save
            end
          end

          if !self.compare_people(person, js)
            person.gender = js['gender'] unless js['gender'].blank?
            person.birthdate = js['birthdate'] unless js['birthdate'].blank?
            person['names']['given_name'] = js['names']['given_name'] unless js['names']['given_name'].blank?
            person['names']['family_name'] = js['names']['family_name'] unless js['names']['family_name'].blank?

            unless js['addresses'].blank?
              person['addresses'] = {} if person['addresses'].blank?
              person['addresses']['current_residence'] = js['addresses']['current_residence'] unless js['addresses']['current_residence'].blank?
              person['addresses']['current_village'] = js['addresses']['current_village'] unless js['addresses']['current_village'].blank?
              person['addresses']['current_district'] = js['addresses']['current_district'] unless js['addresses']['current_district'].blank?
              person['addresses']['current_ta'] = js['addresses']['current_ta'] unless js['addresses']['current_ta'].blank?
              person['addresses']['home_district'] = js['addresses']['home_district'] unless js['addresses']['home_district'].blank?
              person['addresses']['home_ta'] = js['addresses']['home_ta'] unless js['addresses']['home_ta'].blank?
              person['addresses']['home_village'] = js['addresses']['home_village'] unless js['addresses']['home_village'].blank?
            end

            unless js['person_attributes'].blank?
              person['person_attributes'] = {} if person['person_attributes'].blank?
              person['person_attributes']['citizenship'] = js['person_attributes']['citizenship'] unless js['person_attributes']['citizenship'].blank?
              person['person_attributes']['occupation'] = js['person_attributes']['occupation'] unless js['person_attributes']['occupation'].blank?
              person['person_attributes']['home_phone_number'] = js['person_attributes']['home_phone_number'] unless js['person_attributes']['home_phone_number'].blank?
              person['person_attributes']['cell_phone_number'] = js['person_attributes']['cell_phone_number'] unless js['person_attributes']['cell_phone_number'].blank?
              person['person_attributes']['office_phone_number'] = js['person_attributes']['office_phone_number'] unless js['person_attributes']['office_phone_number'].blank?
              person['person_attributes']['race'] = js['person_attributes']['race'] unless js['person_attributes']['race'].blank?
            end
            return person.save
          end
        end

        return true
      end
    return false
  end
    
=begin
  + get_person(npid:String):JSON
  
  
=end
    def self.get_person(npid)
       person = Person.find(npid) rescue nil
       unless person.blank?
          return person
       else
          self.get_person_by_old_national_id(npid)
       end
    end

    def self.get_person_by_old_national_id(npid)
       person = Person.by_old_identification_number.key(npid) rescue nil
       unless person.blank?
          return person
       else
          return nil
       end
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
  end

end
