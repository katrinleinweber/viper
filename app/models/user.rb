# == Schema Information
# Schema version: 49
#
# Table name: users
#
#  id                        :integer(11)     not null, primary key
#  login                     :string(255)     
#  email                     :string(255)     
#  crypted_password          :string(40)      
#  salt                      :string(40)      
#  created_at                :datetime        
#  updated_at                :datetime        
#  remember_token            :string(255)     
#  remember_token_expires_at :datetime        
#  activation_code           :string(40)      
#  activated_at              :datetime        
#  new_email                 :string(255)     
#  email_activation_code     :string(40)      
#  password_reset_code       :string(40)      
#  admin                     :boolean(1)      
#  permalink                 :string(255)     
#  hits                      :integer(11)     default(0)
#  last_seen_at              :datetime        
#  forum_posts_count         :integer(11)     default(0)
#  state                     :string(255)     default("passive")
#  deleted_at                :datetime        
#

class AuthenticationException < StandardError; end
  
class User < ActiveRecord::Base
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken
  include Authorization::StatefulRoles
  
  concerned_with :validation, :activation, :authentication, :messages, :forum_posting
  
  acts_as_ferret :fields => ['login', 'email'], :remote => false
  
  has_one  :profile
  has_one  :avatar
  has_one  :bio
  has_one  :blog
  has_one  :wall
  
  has_many :comments
  has_many :news
  has_many :articles
  
  has_many :friendships
  has_many :friends,            :through => :friendships, :conditions => "status = 'accepted'"
  has_many :requested_friends,  :through => :friendships, :source => :friend, :conditions => "status = 'requested'"
  has_many :pending_friends,    :through => :friendships, :source => :friend, :conditions => "status = 'pending'"
           
  has_many :messages_as_sender,   :foreign_key => 'sender_id',    :class_name => 'Message', :conditions => 'sender_deleted IS NULL', :order => 'created_at DESC'
  has_many :messages_as_receiver, :foreign_key => 'receiver_id',  :class_name => 'Message', :conditions => 'receiver_deleted IS NULL', :order => 'created_at DESC'
  has_many :unread_messages,      :foreign_key => 'receiver_id',  :class_name => 'Message', :conditions => 'read_at IS NULL AND receiver_deleted IS NULL', :order => 'created_at DESC'
  has_many :read_messages,        :foreign_key => 'receiver_id',  :class_name => 'Message', :conditions => 'read_at IS NOT NULL and receiver_deleted IS NULL', :order => 'created_at DESC'
  
  has_many :posts, :order => "#{ForumPost.table_name}.created_at desc", :class_name => 'ForumPost'
  has_many :topics, :order => "#{ForumTopic.table_name}.created_at desc", :class_name => 'ForumTopic'
  
  has_many :moderatorships, :dependent => :delete_all
  has_many :forums, :through => :moderatorships, :source => :forum
  
  FEED_SIZE = 10
  has_many :feeds
  has_many :activities, :through => :feeds,
                        :order => 'created_at DESC', :limit => FEED_SIZE
                        
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :new_email, :password, :password_confirmation
           
  has_permalink :login
  
  attr_readonly :posts_count, :last_seen_at
  
  def self.prefetch_from(records)
    find(:all, :select => 'distinct *', :conditions => ['id in (?)', records.collect(&:user_id).uniq])
  end
  
  def self.index_from(records)
    prefetch_from(records).index_by(&:id)
  end

  def moderator_of?(forum)
    admin? || Moderatorship.exists?(:user_id => id, :forum_id => forum.id)
  end
  
  def hit!
      self.hits += 1
      self.save!
  end
  
  def views() hits end
  
  def setup_for_display!
    self.profile ||= Profile.new
    self.avatar ||= nil
    self.bio ||= Bio.new
    self.blog ||= Blog.new
    self.wall ||= Wall.new
  end
  
  def full_name
    self.profile ||= Profile.new
    self.profile.full_name || self.login
  end
  
  alias name full_name
  
  def first_name
    self.profile ||= Profile.new
    self.profile.first_name.blank? ? self.login : self.profile.first_name
  end
  
  def last_name
    self.profile ||= Profile.new
    self.profile.last_name.blank? ? self.login : self.profile.last_name
  end
  
  def self.find_latest(number = 5)
    find :all, :conditions => ['activation_code IS NULL'], :limit => number, :order => 'created_at DESC'
  end
  
  def self.find_all_for_news_delivery
    find :all, :conditions => ['activation_code IS NULL']
  end
  
  # this is used to keep track of the last time a user has been seen (reading a topic)
  # it is used to know when topics are new or old and which should have the green
  # activity light next to them
  #
  # we cheat by not calling it all the time, but rather only when a user views a topic
  # which means it isn't truly "last seen at" but it does serve it's intended purpose
  #
  # This is now also used to show which users are online... not at accurate as the
  # session based approach, but less code and less overhead.
  def seen!
    now = Time.now.utc
    self.class.update_all ['last_seen_at = ?', now], ['id = ?', id]
    write_attribute :last_seen_at, now
  end
  
  def to_param
    permalink
  end
  
  ## Feeds
  
  def feed
    activities
  end
  
  def recent_activity
    Activity.find_all_by_user_id(self, :order => 'created_at DESC',
                                       :limit => FEED_SIZE)
  end
end
