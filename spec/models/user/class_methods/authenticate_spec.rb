require 'spec_helper'

describe User, '.authenticate' do

  let(:user) { Factory.create(:user) }

  context 'when the given password is blank' do
    it 'returns nil' do
      user.password = ''
      user.save(false)
      User.authenticate(user.login, '').should be_nil
      User.authenticate(user.login, nil).should be_nil
    end
  end

  context 'when the user does not exist' do
    it 'returns nil' do
      User.authenticate('blah', 'bloo').should be_nil
    end
  end

  context 'when the user has an external auth source' do
    let(:auth_source) { Factory.create(:auth_source) }
    let(:user) { Factory.create(:user, :auth_source => auth_source) }

    before(:each) do
      User.stub(:find).and_return(user)
    end

    context 'when that auth source authenticates' do
      it 'returns the user instance' do
        auth_source.
          should_receive(:authenticate).
          with(user.login, user.password).
          and_return(user)
        User.authenticate(user.login, user.password).should == user
      end
    end

    context 'when that auth source does not authenticate the user' do
      it 'returns nil' do
        auth_source.
          should_receive(:authenticate).
          with(user.login, user.password).
          and_return(nil)
        User.authenticate(user.login, user.password).should be_nil
      end
    end

    context 'when the auth source raises an error' do
      it 'raises the error' do
        auth_source.
          should_receive(:authenticate).
          with(user.login, user.password).
          and_raise('woops')
        lambda {
          User.authenticate(user.login, user.password)
        }.should raise_exception('woops')
      end
    end
  end

  context 'when the given password matches the hashed password' do
    it 'returns the user' do
      User.authenticate(user.login, user.password).should == user
    end

    it 'updates the last_login_on on the user' do
      Timecop.freeze do
        User.authenticate(user.login, user.password)
        user.reload
        user.last_login_on.to_i.should == Time.now.to_i
      end
    end
  end

  context 'when the given password does not match the hashed password' do
    it 'returns nil' do
      User.authenticate(user.login, 'foo').should be_nil
    end
  end

  context 'when no user is found' do
    context 'when user attributes are found through AuthSource' do
      let(:user) { User.authenticate('fake login', 'fake password') }

      before(:each) do
        AuthSource.
          stub(:authenticate).
          with('fake login', 'fake password').
          and_return([{ :firstname => 'fake', :lastname => 'user' }])
      end

      it 'builds a new user' do
        user.firstname.should == 'fake'
        user.lastname.should == 'user'
      end

      it 'sets the login for the user' do
        user.login.should == 'fake login'
      end

      it 'sets the default language for the user' do
        user.language.should == 'en'
      end

      context 'when the user is valid' do
        it 'reloads the user for some reason' do
          fake_user = double(:user, {
            :save => true,
            :login= => '',
            :language= => '',
            :new_record? => true,
          })
          User.stub(:new).and_return(fake_user)
          fake_user.should_receive(:reload)
          User.authenticate('fake login', 'fake password')
        end
      end

      context 'when the user is not valid' do
        before(:each) do
          AuthSource.
            stub(:authenticate).
            with('fake login', 'short').
            and_return([{ :firstname => 'fake', :lastname => 'user' }])
        end

        it 'returns a new record' do
          user.new_record?.should be true
        end
      end
    end

    context 'when user attributes are not found through AuthSource' do
      before(:each) do
        AuthSource.stub(:authenticate).with('login', 'password').and_return(nil)
      end

      it 'returns nil' do
        User.authenticate('login', 'password').should be_nil
      end
    end
  end

end
