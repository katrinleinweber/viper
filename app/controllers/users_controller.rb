class IncorrectResetCodeException < StandardError; end

class UsersController < ApplicationController
  
  before_filter :admin_required, :only => [:suspend, :unsuspend, :destroy, :purge]
  before_filter :login_required, :only => [:hub, :edit, :change_email, :change_password, :invite, :send_invite]
  before_filter :protect_user, :only => [:edit, :change_email, :change_password, :invite, :send_invite]
  before_filter :check_logged_in, :only => [:new, :create, :activate]
  before_filter :find_user, :only => [:suspend, :unsuspend, :destroy, :purge]
  
  tab :hub
  tab :community, :only => :show
  tab :register, :only => :new
  tab :articles, :only => :articles
   
  # Display the user's hub
  def hub
    self.sidebar_one = 'sidebar_hub'
    self.maincol_one = 'blogs/maincol_blog'
    self.maincol_two = 'maincol_inbox'
    @user = current_user
    @user.setup_for_display!
    @posts = @user.blog.posts.paginate :page => params[:page]
    @feed = @user.feed
  end
  
  # Display the user's public profile
  def show
    self.sidebar_one = 'sidebar_show'
    self.maincol_one = nil
    self.maincol_two = nil
    
    @user = User.find_by_permalink(params[:id])
    raise ActiveRecord::RecordNotFound if @user.nil?
    @user.setup_for_display!
    @posts = @user.blog.posts.paginate :page => params[:page]
    @user.hit! unless @user == current_user
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Sorry, that user does not exist!"
    redirect_to '/'
  end

  # render new.rhtml
  def new
    @user = User.new
  end
  
  def edit
    @user = self.current_user
  end
  
  def change_email
    @user = self.current_user
    unless params[:user][:email].blank?
      @user.change_email_address(params[:user][:email])
      if @user.save
        @email_changed = true
        redirect_to edit_user_path, :id => @user
        return
      end
    else
      flash[:error] = "Please enter an email address"
    end
    @changing_email = true
    render :action => 'edit'
  end
  
  def change_password
    @user = self.current_user
    if @user.authenticated? params[:current_password]
      unless params[:user][:password].blank?
        @user.password = params[:user][:password]
        @user.password_confirmation = params[:user][:password_confirmation]
        if @user.save
          @password_changed = true
          flash[:notice] = "Your password has been changed"
          redirect_to edit_user_path, :id => @user
          return
        end
      else
        flash[:error] = "New password cannot be blank"
      end
    else
      flash[:error] = "Sorry the current password was incorrect"
    end
    @changing_password = true
    render :action => 'edit'
  end

  def create
    logout_keeping_session!
    @user = User.new(params[:user])
    @user.register! if @user && @user.valid?
    success = @user && @user.valid?
    if success && @user.errors.empty?
      redirect_back_or_default('/')
      flash[:notice] = "Thanks for signing up!  We're sending you an email with your activation code."
    else
      flash[:error]  = "We couldn't set up that account, sorry.  Please try again, or contact an admin (link is above)."
      render :action => 'new'
    end
  end

  def activate
    logout_keeping_session!
    user = User.find_by_activation_code(params[:activation_code]) unless params[:activation_code].blank?
    case
    when (!params[:activation_code].blank?) && user && !user.active?
      user.activate!
      flash[:notice] = "Signup complete! You may now log in to your account"
      redirect_to login_url
    when params[:activation_code].blank?
      flash[:error] = "The activation code was missing.  Please follow the URL from your email."
      redirect_back_or_default('/')
    else 
      flash[:error]  = "We couldn't find a user with that activation code -- check your email? Or maybe you've already activated -- try signing in."
      redirect_back_or_default('/')
    end
  end
  
  def suspend
    @user.suspend! 
    redirect_to users_path
  end

  def unsuspend
    @user.unsuspend! 
    redirect_to users_path
  end

  def destroy
    @user.delete!
    redirect_to users_path
  end

  def purge
    @user.destroy
    redirect_to users_path
  end
  
  def activate_new_email
    flash.clear  
    return unless params[:id].nil? or params[:email_activation_code].nil?
    activator = params[:id] || params[:email_activation_code]
    @user = User.find_by_email_activation_code(activator) 
    if @user and @user.activate_new_email
      redirect_to hub_url
      flash[:notice] = "The email address for your account has been updated" 
    else
      flash[:error] = "Unable to update the email address" 
    end
  end
  
  def forgot_password
    return unless request.post?
    if @user = User.find_for_forgot(params[:email])
      @user.forgot_password
      @user.save
      redirect_to login_url
      flash[:notice] = "A password reset link has been sent to your email address" 
    else
      flash[:error] = "Could not find a user with that email address" 
    end
  end
   
  def reset_password
    @user = User.find_by_password_reset_code(params[:id])
    raise IncorrectResetCodeException if @user.nil?
    return if @user unless params[:password]
    
    if (params[:password] == params[:password_confirmation])
      @user.password = params[:password]
      @user.password_confirmation = params[:password_confirmation]
      flash[:notice] = @user.save ? "Password reset, you may now login" : "Password reset failed"
      @user.reset_password!
      redirect_to(login_path) 
    else
      flash[:error] = "Password mismatch"
    end 
  rescue IncorrectResetCodeException
    logger.error "Invalid Reset Code entered" 
    flash[:error] = "Sorry - That is an invalid password reset code. Please check your code and try again. (Perhaps your email client inserted a carriage return?)" 
    redirect_to(login_path)
  end
  
  def invite
    @invite = Invite.new
  end
  
  def send_invite
    @invite = Invite.new(params[:invite])
    @invite.user = @user
    if @invite.save
      @invite.send_invites
      flash[:notice] = "Invite's have been sent"
      redirect_to hub_url
    else
      render :action => :invite
    end
  end
  
  def articles
    self.disable_maincols
    self.sidebar_one = 'sidebar_show'
    @user = User.find_by_permalink(params[:id])
    @articles = @user.articles
  end
  
protected
  
  def protect_user
    @user = User.find_by_permalink(params[:id])
    unless @user == current_user
      flash[:error] = "That isn't your user!"
      redirect_to hub_url
      return false
    end    
  end
  
  def check_logged_in
    unless @user.nil?
      flash[:error] = "Sorry, you already have a user account!"
      redirect_to hub_url
      return false
    end
  end
  
  def find_user
    @user = User.find_by_permalink(params[:id])
  end

end
