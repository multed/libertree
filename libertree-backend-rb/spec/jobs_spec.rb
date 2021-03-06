require 'spec_helper'
require 'tmpdir'
require 'libertree/client'
require_relative '../lib/jobs'

describe Jobs do
  LM = Libertree::Model
  before :all do
    @server = LM::Server.create( FactoryGirl.attributes_for(:server) )
    @server.domain = "here"
    @other_server = LM::Server.create( FactoryGirl.attributes_for(:server) )
    @other_server.domain = "faraway"
    @member = LM::Member.create( FactoryGirl.attributes_for(:member, :server_id => @server.id) )
    @other_member = LM::Member.create( FactoryGirl.attributes_for(:member, :server_id => @other_server.id) )
  end

  describe Jobs::River do
    describe 'Refresh#perform' do
      it 'calls #refresh_posts on the identified river' do
        pending
      end
    end

    describe 'RefreshAll#perform' do
      it "calls #refresh_posts on all of the account's rivers" do
        pending
      end
    end
  end

  describe Jobs::Email::Simple, "#perform" do
    it 'sends an email' do
      Mail.defaults do
        delivery_method :test
      end

      Mail::TestMailer.deliveries.clear
      Mail::TestMailer.deliveries.length.should == 0

      Jobs::Email::Simple.from = "sender@localhost"
      Jobs::Email::Simple.perform({ 'to'      => 'test@localhost',
                                    'subject' => 'testing',
                                    'body'    => 'this is a test' })
      Mail::TestMailer.deliveries.length.should == 1
    end
  end

  describe Jobs::Email::Forward, "#perform" do
    before :all do
      @account = LM::Account.create(username: "libertreejobs",
                                    email: "email@localhost",
                                    password_encrypted: BCrypt::Password.create("1234"))
      @message = LM::Message.create(sender_member_id: @account.member.id, text: 'test')
    end
    it 'triggers Jobs::Email::Simple.perform' do
      expect( Jobs::Email::Simple ).to receive(:perform)
      Jobs::Email::Simple.stub(:perform)
      Jobs::Email::Forward.perform({ 'username'   => @account.username,
                                     'message_id' => @message.id })
    end

    it 'raises JobInvalid if there is no email address' do
      @account.email = nil
      @account.save
      expect {
        Jobs::Email::Forward.perform({ 'username'   => @account.username,
                                       'message_id' => @message.id })
      }.to raise_exception(Libertree::JobInvalid)
    end
  end

  describe Jobs::Request do
    before :each do
      @client = double("Client")
      @client.stub(:request) {|domain, args|
        [ true, Nokogiri::XML.fragment("<iq />") ]
      }
      Jobs::Request.stub(:client) { @client }
    end

    describe 'RequestJob.with_tree' do
      it 'raises JobInvalid if the server has no domain' do
        server = LM::Server.create( FactoryGirl.attributes_for(:server) )
        server.domain = nil
        server.save
        expect { Jobs::Request::RequestJob.with_tree(server.id, nil, nil) }.
          to raise_exception(Libertree::JobInvalid)

        server.domain = ""
        server.save
        expect { Jobs::Request::RequestJob.with_tree(server.id, nil, nil) }.
          to raise_exception(Libertree::JobInvalid)
      end
    end

    describe 'CHAT#perform' do
      it 'calls req_chat with a valid chat message' do
        msg = LM::ChatMessage.create( from_member_id: @member.id,
                                      to_member_id: @other_member.id,
                                      text: "hello" )
        params = {
          'chat_message_id' => msg.id,
          'server_id'       => msg.recipient.tree.id,
        }

        @client.stub(:req_chat)
        @client.should_receive(:req_chat)
        Jobs::Request::CHAT.perform( params )
      end
    end

    describe 'COMMENT#perform' do
      it 'calls req_comment with a valid comment' do
        # remote post
        post = LM::Post.create( member_id: @other_member.id,
                                text: "this is a post" )
        comment = LM::Comment.create( member_id: @member.id,
                                      post_id: post.id,
                                      text: "hello" )
        params = {
          'comment_id' => comment.id,
          'server_id'  => post.member.server_id,
        }
        Jobs::Request.stub(:conf) {
          { :frontend_url_base => 'not.important.net' }
        }
        @client.stub(:req_comment)
        @client.should_receive(:req_comment)
        @client.should_receive(:request).with(comment.post.member.tree.domain, anything())
        Jobs::Request::COMMENT.perform( params )
      end
    end

    describe 'COMMENT_DELETE#perform' do
      it 'calls req_comment_delete with a valid comment' do
        # remote post
        post = LM::Post.create( member_id: @other_member.id,
                                text: "this is a post" )
        comment = LM::Comment.create( member_id: @member.id,
                                      post_id: post.id,
                                      text: "hello" )
        params = {
          'comment_id' => comment.id,
          'server_id'  => post.member.server_id,
        }
        @client.stub(:req_comment_delete)
        @client.should_receive(:req_comment_delete)
        @client.should_receive(:request).with(comment.post.member.tree.domain, anything())
        Jobs::Request::COMMENT_DELETE.perform( params )
      end
    end

    describe 'COMMENT_LIKE#perform' do
      pending
    end

    describe 'COMMENT_LIKE_DELETE#perform' do
      pending
    end

    describe 'FOREST#perform' do
      pending
    end

    describe 'INTRODUCE#perform' do
      it 'calls req_introduce' do
        @client.stub(:req_introduce)
        expect( @client ).to receive(:req_introduce)
        expect( @client ).to receive(:request)
        Jobs::Request::INTRODUCE.perform({'server_id' => @other_server.id})
      end
    end

    describe 'MEMBER#perform' do
      pending
    end

    describe 'MEMBER_DELETE#perform' do
      pending
    end

    describe 'MESSAGE#perform' do
      pending
    end

    describe 'POOL#perform' do
      pending
    end

    describe 'POOL_DELETE#perform' do
      pending
    end

    describe 'POOL_POST#perform' do
      pending
    end

    describe 'POOL_POST_DELETE#perform' do
      pending
    end

    describe 'POST#perform' do
      pending
    end

    describe 'POST_DELETE#perform' do
      pending
    end

    describe 'POST_LIKE#perform' do
      pending
    end

    describe 'POST_LIKE_DELETE#perform' do
      pending
    end
  end
end

describe Jobs::Http do
  describe 'Avatar#perform' do
    before :each do
      account = Libertree::Model::Account.create( FactoryGirl.attributes_for(:account) )
      @member = account.member
      Jobs::Http::Avatar.options = {
        'avatar_dir' => Dir.tmpdir
      }
    end

    it 'raises JobInvalid with an invalid URL' do
      params = {
        'member_id' => @member.id,
        'avatar_url' => "not a valid URL"
      }
      expect { Jobs::Http::Avatar.perform(params) }.to raise_exception(Libertree::JobInvalid)
    end
  end

  describe 'Embed#perform' do
    it 'raises JobInvalid with an invalid URL' do
      params = {
        'url' => 'localhost',
      }
      expect { Jobs::Http::Embed.perform(params) }.to raise_exception(Libertree::JobInvalid)
    end
  end
end
