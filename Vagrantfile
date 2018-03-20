$system = <<SCRIPT
yum install -y git ruby18* rubygems18* rubygem18-rake
alternatives --set ruby /usr/bin/ruby1.8

yum install -y autoconf automake libtool
yum install -y ImageMagick-devel mysql-devel postgresql-devel sqlite-devel libffi-devel
yum install -y postgresql postgresql-server

sudo service postgresql initdb
sudo service postgresql start

sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'tree';"

sudo echo "" > /var/lib/pgsql9/data/pg_hba.conf
sudo echo "local   all             all                                     md5" >> /var/lib/pgsql9/data/pg_hba.conf
sudo echo "host    all             all             127.0.0.1/32            md5" >> /var/lib/pgsql9/data/pg_hba.conf
sudo echo "host    all             all             ::1/128                 md5" >> /var/lib/pgsql9/data/pg_hba.conf

sudo service postgresql restart

sudo gem update --system 1.8.25
gem install bundler
gem install ffi -v 1.9.3
SCRIPT

$app = <<SCRIPT
cd /vagrant/

/usr/bin/bundle update
/usr/bin/bundle install

export BETTER_S3_ACCESS_KEY_ID=trash
export BETTER_S3_SECRET_ACCESS_KEY=trash
export BETTER_SESSION_KEY=test
export BETTER_SESSION_SECRET=bf6f061c510e8597d32976df19fcbdf5

echo "" >> ~/.bash_profile
echo "export BETTER_S3_ACCESS_KEY_ID=trash"                          >> ~/.bash_profile
echo "export BETTER_S3_SECRET_ACCESS_KEY=trash"                      >> ~/.bash_profile
echo "export BETTER_SESSION_KEY=test"                                >> ~/.bash_profile 
echo "export BETTER_SESSION_SECRET=bf6f061c510e8597d32976df19fcbdf5" >> ~/.bash_profile

/usr/bin/bundle exec rake db:create:all
/usr/bin/bundle exec rake db:schema:load
/usr/bin/bundle exec rake db:seed
/usr/bin/bundle exec rake db:test:prepare
#/usr/bin/bundle exec rake spec
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box         = "mvbcoding/awslinux"
  config.ssh.insert_key = false
  config.vm.provision "shell", inline: $system
  config.vm.provision "shell", inline: $app, privileged: false
  config.vm.network "forwarded_port", guest: 3000, host: 8080

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--cableconnected1", "on"]
  end
end
