class User < ActiveRecord::Base

	#acts_as_rated :no_rater => true
	acts_as_rated :with_stats_table => true, :no_rater => true

	has_many :posts
	has_many :orig_posts

	validates_uniqueness_of :username, :case_sensitive => false
	validates_uniqueness_of :email, :case_sensitive => false

	after_create :register_user_to_fb

	def self.top(num)
	  user_cols = User.column_names.collect {|c| "users.#{c}"}.join(",")
	  return User.find_by_sql("SELECT #{user_cols}, count(posts.id) AS post_count FROM users LEFT OUTER JOIN posts ON posts.user_id = users.id GROUP BY users.id, #{user_cols} ORDER BY post_count DESC LIMIT 5")
	end

	#find the user in the database, first by the facebook user id and if that fails through the email hash
	def self.find_by_fb_user(fb_user)
		User.find_by_fb_user_id(fb_user.uid) || User.find_by_email_hash(fb_user.email_hashes)
	end
	
	#Take the data returned from facebook and create a new user from it.
	#We don't get the email from Facebook and because a facebooker can only login through Connect we just generate a unique login name for them.
	#If you were using username to display to people you might want to get them to select one after registering through Facebook Connect
	def self.create_from_fb_connect(fb_user)
		new_facebooker = User.new(:username => "fb_#{fb_user.uid}", :email => "")
		new_facebooker.fb_user_id = fb_user.uid.to_i
	
	        #We need to save without validations
	        new_facebooker.save
	        #new_facebooker.register_user_to_fb
	end
	
	#We are going to connect this user object with a facebook id. But only ever one account.
	def link_fb_connect(fb_user_id)
		unless fb_user_id.nil?
			#check for existing account
			existing_fb_user = User.find_by_fb_user_id(fb_user_id)
	
	                #unlink the existing account
	                unless existing_fb_user.nil?
				existing_fb_user.fb_user_id = nil
	                        existing_fb_user.save(false)
	                end
	
	                #link the new one
	                self.fb_user_id = fb_user_id
	                save(false)
		end
	end
	
	#The Facebook registers user method is going to send the users email hash and our account id to Facebook
	#We need this so Facebook can find friends on our local application even if they have not connect through connect
	#We then use the email hash in the database to later identify a user from Facebook with a local user
	def register_user_to_fb
		users = {:email => email, :account_id => id}
	        Facebooker::User.register([users])
	        self.email_hash = Facebooker::User.hash_email(email)
	        save(false)
	end
	
end
