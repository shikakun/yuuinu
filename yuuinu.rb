# coding: utf-8

Sequel::Model.plugin(:schema)

db = {
  user:     ENV['USER'],
  dbname:   ENV['DBNAME'],
  password: ENV['PASSWORD'],
  host:     ENV['HOST']
}

configure :development do
  DB = Sequel.connect("sqlite://yuuinu.db")
end

configure :production do
  DB = Sequel.connect("mysql2://#{db[:user]}:#{db[:password]}@#{db[:host]}/#{db[:dbname]}")
end

class YuuInuTable < Sequel::Model
  unless table_exists?
    set_schema do
      primary_key :id
      String :uid
      String :name
      String :nickname
      String :image
      String :token
      String :secret
      DateTime :created_at
      DateTime :updated_at
    end
    create_table
  end
end

use Rack::Session::Cookie,
  :key => 'rack.session',
  :path => '/',
  :expire_after => 3600,
  :secret => ENV['SESSION_SECRET']

use OmniAuth::Builder do
  provider :twitter, ENV['TWITTER_CONSUMER_KEY'], ENV['TWITTER_CONSUMER_SECRET']
end

before do
  Twitter.configure do |config|
    config.consumer_key       = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret    = ENV['TWITTER_CONSUMER_SECRET']
    config.oauth_token        = session['token']
    config.oauth_token_secret = session['secret']
  end
end

def tweet(tweets)
  if settings.environment == :production
    twitter_client = Twitter::Client.new
    twitter_client.update(tweets)
  elsif settings.environment == :development
    flash.next[:info] = tweets
  end
end

def timeago(times)
  diff = Time.now.to_i - times.to_i
  case diff
    when 0 then 'たったいま'
    when 1..59 then diff.to_s+'秒前に' 
    when 60..3540 then (diff/60).to_i.to_s+'分前に'
    when 3541..82800 then ((diff+99)/3600).to_i.to_s+'時間前に'
    when 82801..172000 then 'きのう'
    when 172001..518400 then ((diff+800)/(60*60*24)).to_i.to_s+'日前に'
    when 518400..1036800 then '先週'
    else ((diff+180000)/(60*60*24*7)).to_i.to_s+'週間前に'
  end
end

not_found do
  redirect "/"
end

error do
  redirect "/inu"
end

get "/" do
  @dogs = YuuInuTable.order_by(:id.desc)
  @repeater = []
  @dogs.each { |dog|
    @repeater << dog.uid
  }
  @repeater = @repeater.group_by{|i| i}.reject{|k,v| v.one?}.keys
  slim :index
end

get "/inu" do
  redirect "/auth/twitter"
end

get "/auth/:provider/callback" do
  auth = request.env['omniauth.auth']
  session['uid'] = auth['uid']
  session['name'] = auth['info']['name']
  session['nickname'] = auth['info']['nickname']
  session['image'] = auth['info']['image']
  session['token'] = auth['credentials']['token']
  session['secret'] = auth['credentials']['secret']
  if YuuInuTable.filter(uid: session['uid']).empty?
    tweet(session['name'] + 'が犬になりました http://yuui.nu/')
  else
    tweet(session['name'] + 'は犬のままです http://yuui.nu/')
  end
  YuuInuTable.create(
    :uid => session['uid'],
    :name => session['name'],
    :nickname => session['nickname'],
    :image => session['image'],
    :token => session['token'],
    :secret => session['secret'],
    :created_at => Time.now,
    :updated_at => Time.now
  )
  redirect "/"
end
