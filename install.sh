#!/bin/bash

# -------------------------
# install packages
# -------------------------
sudo apt-get update -y
sudo apt-get install -y --force-yes postgresql-9.3-postgis-2.1 autoconf bind9-host \
                                    bison build-essential coreutils curl daemontools \
                                    dnsutils ed git imagemagick iputils-tracepath \
                                    language-pack-en libbz2-dev libcurl4-openssl-dev \
                                    libevent-dev libglib2.0-dev libjpeg-dev \
                                    libmagickwand-dev libncurses5-dev libpq-dev libpq5 \
                                    libreadline6-dev libssl-dev libxml2-dev libxslt-dev \
                                    netcat-openbsd openssh-client openssh-server \
                                    postgresql-server-dev-9.3 python python-dev \
                                    ruby ruby-dev socat syslinux tar telnet zip zlib1g-dev
cd / && sudo rm -rf /var/cache/apt/archives/*.deb

# -------------------------
# postgres
# -------------------------
dbname="werckerdb"
user="postgres"
passwrod="wercker"
# configure access for local postgres user
if sudo grep -Exq '^local\s+all\s+postgres\s+\w+' /etc/postgresql/9.3/main/pg_hba.conf; then
    sudo sed -i -r -e 's/local\s+all\s+postgres\s+\w+/local all postgres  trust/' /etc/postgresql/9.3/main/pg_hba.conf
else
    sudo -- sh -c "echo 'local all postgres  trust' >> /etc/postgresql/9.3/main/pg_hba.conf"
fi
# configure access for local database access
if sudo grep -Exq '^host\s+${dbname}\s+${user}\s+0\.0\.0\.0\/32\s+\w+' /etc/postgresql/9.3/main/pg_hba.conf; then
    sudo sed -i -r -e 's/host\s+${dbname}\s+${user}\s+0\.0\.0\.0\/32\s+\w+/host ${dbname} ${user} 0.0.0.0/32 md5/' /etc/postgresql/9.3/main/pg_hba.conf
else
    sudo -- sh -c "echo 'host ${dbname} ${user} 0.0.0.0/32 md5' >> /etc/postgresql/9.3/main/pg_hba.conf"
fi
# configure access for tcp database access
if sudo grep -Exq '^local\s+${dbname}\s+${user}\s+\w+' /etc/postgresql/9.3/main/pg_hba.conf; then
    sudo sed -i -r -e 's/local\s+${dbname}\s+${user}\s+\w+/local ${dbname} ${user}  md5/' /etc/postgresql/9.3/main/pg_hba.conf
else
    sudo -- sh -c "echo 'local ${dbname} ${user}  md5' >> /etc/postgresql/9.3/main/pg_hba.conf"
fi
# restart postgres and create database with postgis extensions
sudo service postgresql restart
sudo -- su postgres -c "createdb -O ${user} ${dbname}"
sudo -- su ${user} -c "PGPASSWORD=${passwrod} psql -c 'CREATE EXTENSION postgis;' -d ${dbname}"
sudo -- su ${user} -c "PGPASSWORD=${passwrod} psql -c 'CREATE EXTENSION postgis_topology;' -d ${dbname}"
# check database creation
echo -n "Checking if database created... "
if sudo -- su postgres -c "psql -c 'SELECT datname FROM pg_database WHERE datistemplate=false;'" | grep -Eqx "\s*${dbname}"; then
    echo "yes"
else
    echo "no"
    exit 1
fi
# check database postgis extension
echo -n "Checking if postgis extension created... "
if sudo -- su postgres -c "psql -d ${dbname} -c 'SELECT PostGIS_full_version();'" | grep -q "POSTGIS="; then
    echo "yes"
else
    echo "no"
    exit 1
fi


# -------------------------
# download geos and proj
# -------------------------
curl -sL https://s3-us-west-2.amazonaws.com/plandex-heroku/cedar-14/proj-4.8.0-1.tar.gz -o /tmp/proj.tar.gz
curl -sL https://s3-us-west-2.amazonaws.com/plandex-heroku/cedar-14/geos-3.4.2-1.tar.gz -o /tmp/geos.tar.gz
sudo tar -zxf /tmp/proj.tar.gz -C /usr
sudo tar -zxf /tmp/geos.tar.gz -C /usr
sudo ldconfig


# -------------------------
# install and configure rbenv and ruby
# -------------------------
git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
export PATH="$HOME/.rbenv/bin:$PATH"
rbenv init -
rbenv install 2.1.5
rbenv rehash
rbenv global 2.1.5
~/.rbenv/shims/ruby --version
~/.rbenv/shims/gem install bundler --no-rdoc --no-ri
~/.rbenv/shims/gem install rgeo --no-rdoc --no-ri
# check if GEOS supported in rgeo gem
echo -n "Checking if GEOS library linked to rgeo gem... "
~/.rbenv/shims/ruby -e 'require "rgeo";puts RGeo::Geos.supported? ? "yes":"no"'


# -------------------------
# cleanup
# -------------------------
rm -rf /tmp/*