class ForumTopicsController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  before_filter :find_forum
  before_filter :find_topic, :only => [:show, :edit, :update, :destroy]
  before_filter :setup_display
  
  tab :forums
  
  def index
    respond_to do |format|
      format.html { redirect_to forum_path(@forum) }
      format.xml do
        @topics = find_forum.topics.paginate(:page => current_page)
        render :xml  => @topics
      end
    end
  end
  
  def edit
  end

  def show
    respond_to do |format|
      format.html do
        if logged_in?
          current_user.seen!
          (session[:topics] ||= {})[@topic.id] = Time.now.utc
        end
        
        @topic.hit! unless logged_in? && @topic.user_id == current_user.id
        @posts = @topic.posts.paginate :page => current_page
        @post  = ForumPost.new
      end
      format.xml  { render :xml  => @topic }
    end
  end

  def new
    @topic = ForumTopic.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml  => @topic }
    end
  end

  def create
    @topic = current_user.post_to_forum @forum, params[:topic]

    respond_to do |format|
      if @topic.new_record?
        format.html { render :action => "new" }
        format.xml  { render :xml  => @topic.errors, :status => :unprocessable_entity }
      else
        flash[:notice] = 'Topic was successfully created.'
        format.html { redirect_to(forum_topic_path(@forum, @topic)) }
        format.xml  { render :xml  => @topic, :status => :created, :location => forum_topic_url(@forum, @topic) }
      end
    end
  end

  def update
    current_user.revise @topic, params[:topic]
    respond_to do |format|
      if @topic.errors.empty?
        flash[:notice] = 'Topic was successfully updated.'
        format.html { redirect_to(forum_topic_path(@forum, @topic)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml  => @topic.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @topic.destroy

    respond_to do |format|
      format.html { redirect_to(@forum) }
      format.xml  { head :ok }
    end
  end
  
protected
  def find_forum
    @forum = Forum.find_by_permalink(params[:forum_id])
  end
  
  def find_topic
    @topic = @forum.topics.find_by_permalink(params[:id])
  end
  
  def setup_display
    self.sidebar_one = nil
    self.disable_maincols
  end
end
