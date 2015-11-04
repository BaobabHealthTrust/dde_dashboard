module Utils

  class UserUtil
  
    def self.create(params)
      user = User.new()
      user.username = params[:user]['username']
      user.password_hash = params[:user]['password']
      user.first_name = params[:user]['first_name']
      user.last_name = params[:user]['last_name']
      user.role = params[:user]['role']
      user.site_code = Site.current_code
      user.email = params[:user]['email']
      user.save
      return user
    end
  
    def self.edit(params)
      if params[:edit_action] == 'password_only'
        cur_user = User.current
        cur_user.password_hash = params[:user]['password']
        cur_user.save
      elsif params[:edit_action] == 'edit'
        cur_user = Utils::UserUtil.get_active_user(params[:username])
        cur_user.first_name = params[:user]['first_name']
        cur_user.last_name = params[:user]['last_name']
        cur_user.role = params[:user]['role']
        cur_user.email = params[:user]['email']
        cur_user.save
      end
      
      true
    end

    def self.get_active_user(username)
      user_hash = User.active_users.keys [username]
      return if user_hash.blank?
      username = user_hash.rows.first['value']['username']
      User.find username
    end

  end
end
