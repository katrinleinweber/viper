ActionController::Routing::Routes.draw do |map|

  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  map.connect '', :controller => "site"

  # User resources
  map.resources :users, :member => { :change_email => :put, :change_password => :put, :invite => :get, :send_invite => :put, :articles => :get } do |user|
    user.resource :profile
    user.resource :avatar, :member => { :crop => :put }
    user.resource :bio
    user.resources :messages, :collection => { :sent => :get }, :member => { :reply => :get }
    user.resource :wall do |wall|
      wall.resources :comments
    end
  end
  map.resource  :sessions
  
  # User named routes
  map.activate  'user/activate/:activation_code', :controller => 'users', :action => 'activate'
  map.signup    'user/signup',    :controller => 'users',    :action => 'new'
  map.login     'user/login',     :controller => 'sessions', :action => 'new'
  map.hub       'user/hub',       :controller => 'users',    :action => 'hub'
  map.logout    'user/logout',    :controller => 'sessions', :action => 'destroy'
  map.activate_new_email  'user/activate_new_email/:email_activation_code', :controller => 'users', :action => 'activate_new_email'
  map.forgot_password     'user/forgot_password', :controller => 'users', :action => 'forgot_password'
  map.reset_password      'user/reset_password/:id', :controller => 'users', :action => 'reset_password'
  
  # Blog resources
  map.resources :blogs do |blog|
    blog.resources :posts do |post|
      post.resources :comments
    end
  end
  
  # News resources
  map.resources :news, :singular => :news_item
  
  # Article resources
  map.resources :categories do |category|
    category.resources :articles
  end
  
  # Comment resources
  map.resources :comments, :collection => {:destroy_multiple => :delete},
                :member => {:approve => :put, :reject => :put}
                
  # Admin namespace
#  map.namespace :admin do |admin|
#    admin.connect '', :controller => :dashboard
#  end

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  #map.connect ':controller/service.wsdl', :action => 'wsdl'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
end
