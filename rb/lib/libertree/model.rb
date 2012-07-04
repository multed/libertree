require 'libertree/db'

# Connect to the DB so the ORM can get what it needs to get
Libertree::DB.dbh

require_relative 'model/account'
require_relative 'model/chat-message'
require_relative 'model/comment'
require_relative 'model/comment-like'
require_relative 'model/forest'
require_relative 'model/invitation'
require_relative 'model/job'
require_relative 'model/member'
require_relative 'model/message'
require_relative 'model/notification'
require_relative 'model/post'
require_relative 'model/post-hidden'
require_relative 'model/post-like'
require_relative 'model/post-revision'
require_relative 'model/profile'
require_relative 'model/river'
require_relative 'model/server'
require_relative 'model/session-account'
require_relative 'model/url-expansion'
