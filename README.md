## Installing Vitess manually on Debian Bookworm.

This Vitess script will install Vitess 20.0.1 on MySQL 8.0.32 using Debian Bookworm as an operating system. Vitess requires MySQL 8.0 at the moment because some features are deprecated in 8.4. And the configuration package for MySQL 8.0.32 requires Bookworm.

### Prepare ETCD system

This should be a separate cluster from the Vitess cluster.

First we need to install a couple of packages, etcd for the topology.

```
sudo apt install -y etcd-server etcd-client wget
```

#### Configure ETCD

We will edit the etcd script and add the configuration below.

```
sudo vi /etc/default/etcd
```

This needs to be added to all servers only switching the IP addresses and name for each host.

```
ETCD_NAME="vitess1"
ETCD_DATA_DIR="/var/lib/etcd/mycluster"
ETCD_LISTEN_PEER_URLS="http://192.168.1.1:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.1.1:2379,http://localhost:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.1.1:2380"
ETCD_INITIAL_CLUSTER="vitess1=http://192.168.1.1:2380,vitess2=http://192.168.1.2:2380,vitess3=http://192.168.1.3:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="vitess-cluster-1"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.1.1:2379"
```

After the configuration we need to restart all 3 services and ensure that we have a working cluster.

```
sudo systemctl restart etcd
sudo systemctl status etcd
```

#### Creating a cell

A cell is a geograpical place that will encapsulate for quick access. So if we fetch data in one cell we will first look for it in this cell and if we can fetch it we will contact other cells to find the data.

First we need to download the vitess repository.

```
version=20.0.1
file=vitess-${version}-003c441.tar.gz
wget https://github.com/vitessio/vitess/releases/download/v${version}/${file}
tar -xzf ${file}
cd ${file/.tar.gz/}
```

We run the controller client command on the internal server to add new cell information. Important is to define the addresses to the RPC port of our ETCD cluster correctly or we will have problems when our services want to connect later on. This will create the first cell called zone1.

```
./bin/vtctldclient --server internal AddCellInfo --root "/vitess/zone1" --server-address "192.168.1.1:2380,192.168.1.2:2380,192.168.1.3:2380" "zone1"
```


#### Prepare Mysql


First we need to install a couple of packages, curl and wget for downloading packages and last but not least gnupg for crypto and unzip for a package we need later.

```
sudo apt install -y curl wget gnupg unzip lsb-release git
```

We download the MySQL configuration package and install it. Make sure to choose the mysql-8.0 option when installing.
```
wget https://repo.mysql.com/mysql-apt-config_0.8.32-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.32-1_all.deb
```

After we installed the configuration package we can update our repository and install MySQL. The database created during installation is something we don't use so we will stop mysql and disable after install.

```
sudo apt update
sudo apt install -y mysql-server
sudo systemctl disable mysql
sudo systemctl stop mysql
```

#### Prepare vitess user

We will  create a new user and group on the system who will run all the services and build the node admin.

```
sudo groupadd vitess
sudo useradd -g vitess -m -s /bin/bash vitess
sudo su vitess
```

Next we install nvm used to install and enable node 20.

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

nvm install 20
nvm use 20
```

Log out of the vitess account to the account that have sudo access again.

#### AppArmor

We need to ensure that AppArmor isn't enabled for the MySQL database or else we will get permissions issues. Normally this is not enabled on Debian bookworm.
```
# Debian and Ubuntu
sudo ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/
sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld

# The following command should return an empty result:
sudo aa-status | grep mysqld
```

#### Vitess installation

First we will download the Vitess 20.0.1, unpack and enter that directory.
```
version=20.0.1
file=vitess-${version}-003c441.tar.gz
wget https://github.com/vitessio/vitess/releases/download/v${version}/${file}
tar -xzf ${file}
cd ${file/.tar.gz/}
```

From this directory we will copy over the files to /usr/local/vitess and setting permissions to our new vitess user.

```
sudo mkdir -p /usr/local/vitess
sudo cp -r * /usr/local/vitess/
sudo mkdir -p /var/lib/vitess/logs
sudo chown -R vitess:vitess /var/lib/vitess
```

If you mounted any drives to run MySQL on you should give permissions to Vitess for these drives.

```
sudo mkdir -p /vt/mysql1
sudo mkdir -p /vt/mysql2
sudo mkdir -p /vt/mysql3
sudo chown -R vitess:vitess /vt/mysql*
```

Next we will prepare the newly copied Vitess directory. I want the admin interface to be in /var/lib/vitess so we can build it there later. Updating the permissions as we go.

```
cd /usr/local/vitess/
sudo mv web/vtadmin /var/lib/vitess
sudo chown -R vitess:vitess /var/lib/vitess
```

#### Building admin interface.

After we copied the things we want from examples we can remove the rest and I also want to remove the node_module directory of the administrative interface as this will fail during building. Some of the dependencies might have been built for another system and will fail.

```
sudo rm -rf examples
sudo rm -rf /var/lib/vitess/vtadmin/node_modules/
```

Now let's change over to the vitess user and build the admin interface using the node version we installed earlier.

```
sudo su vitess
```

Enter the directory of the vtadmin interface and run the build script.

```
cd /var/lib/vitess/vtadmin/
./build.sh
```

Make sure the build was successful.
Log out of the vitess account to the account that have sudo access again.

### Preparing scripts

First we need to fetch repository with scripts.

```
cd ~
git clone https://github.com/kalaspuffar/vitess-scripts.git
```

We need to create and copy couple of directories for configuration files used by the admin and orchistrator interface.
```
sudo mkdir -p /var/lib/vitess/vtadmin/config
sudo mkdir -p /var/lib/vitess/vtorc
sudo cp -R vitess-scripts/vtadmin/* /var/lib/vitess/vtadmin/config
sudo cp -R vitess-scripts/vtorc/* /var/lib/vitess/vtorc
```

We will copy the scripts to vitess that we later can use to initialize the databases.
```
sudo cp -R vitess-scripts/scripts/ /usr/local/vitess/
```

We will copy the users file containing our single user of vitess:qwerty so we later can login and test the interface, for production this password should ofcourse be updated.
```
sudo cp vitess-scripts/users.json /var/lib/vitess/
sudo chown -R vitess:vitess /var/lib/vitess
```

We also copy the systemd start up scripts over to the directory used for services.
```
sudo cp vitess-scripts/systemd/* /etc/systemd/system
```

Next we fetch all the scripts from my repository for systemd and update them as needed for the system. The files `vitess.env`, `mysql[1-3].service` and `mysql[1-3]-vtab.service` needs updating for your current installation. Setting unique UID and other values in the vitess environment.
```
cd /etc/systemd/system
sudo vi vitess.env
sudo vi mysql1.service
sudo vi mysql2.service
sudo vi mysql3.service
sudo vi mysql1-vtab.service
sudo vi mysql2-vtab.service
sudo vi mysql3-vtab.service
```

### Initiate the databases

Now let's change over to the vitess user and initiate the database directories.

```
sudo su vitess
```

Initate databases on host1
```
cd ~
/usr/local/vitess/scripts/mysqlctl-init.sh 101 /vt/mysql1
/usr/local/vitess/scripts/mysqlctl-init.sh 102 /vt/mysql2
/usr/local/vitess/scripts/mysqlctl-init.sh 103 /vt/mysql3
```

Initate databases on host2
```
cd ~
/usr/local/vitess/scripts/mysqlctl-init.sh 201 /vt/mysql1
/usr/local/vitess/scripts/mysqlctl-init.sh 202 /vt/mysql2
/usr/local/vitess/scripts/mysqlctl-init.sh 203 /vt/mysql3
```

Initate databases on host3
```
cd ~
/usr/local/vitess/scripts/mysqlctl-init.sh 301 /vt/mysql1
/usr/local/vitess/scripts/mysqlctl-init.sh 302 /vt/mysql2
/usr/local/vitess/scripts/mysqlctl-init.sh 303 /vt/mysql3
```

Log out of the vitess account to the account that have sudo access again.

#### Setup discovery configuration

Lastly we will update `discovery.json` in the `/var/lib/vitess/vtadmin/config` directory to specify all the hosts we want to run controllers and vtgates on. This is so the admin interface will find them easily.

```
{
    "vtctlds": [
        {
            "host": {
                "fqdn": "host1:15000",
                "hostname": "host1:15999"
            }
        },
        {
            "host": {
                "fqdn": "host2:15000",
                "hostname": "host2:15999"
            }
        },
        {
            "host": {
                "fqdn": "host3:15000",
                "hostname": "host3:15999"
            }
        }
    ],
    "vtgates": [
        {
            "host": {
                "fqdn": "host1:15001",
                "hostname": "host1:15991"
            }
        },
        {
            "host": {
                "fqdn": "host2:15001",
                "hostname": "host2:15991"
            }
        },
        {
            "host": {
                "fqdn": "host3:15001",
                "hostname": "host3:15991"
            }
        }

    ]
}
```

### Starting the cluster

First we will start the controller daemon after we have reloaded all the scripts we updated earlier.

```
sudo systemctl daemon-reload
sudo systemctl start vtctld
sudo systemctl status vtctld
```

**!!! IMPORTANT !!!**
When the controller is running we need to create our keyspace. This needs to be done before we start any other services.

```
vtctldclient --server localhost:15999 CreateKeyspace --durability-policy=semi_sync commerce
```

Now we can start all the mysql and vttablet services that we have on this host.

```
sudo systemctl start mysql1
sudo systemctl status mysql1
sudo systemctl start mysql2
sudo systemctl status mysql2
sudo systemctl start mysql3
sudo systemctl status mysql3
sudo systemctl start mysql1-vtab
sudo systemctl status mysql1-vtab
sudo systemctl start mysql2-vtab
sudo systemctl status mysql2-vtab
sudo systemctl start mysql3-vtab
sudo systemctl status mysql3-vtab
```

When the MySQL services have been started we should have a couple of replicas but no primary. The controller will not do any changes until the orchastrator plans them so lets start that service next.

```
sudo systemctl start vtorc
sudo systemctl status vtorc
```

If you now check your tablets on ports like host:1510[1-3]/debug/status you should be find one that is primary.

When this is running we can start the vtgate service that will serve traffic and send it through to our tablets.
```
sudo systemctl start vtgate
sudo systemctl status vtgate
```

Last service is the administrator interface.
```
sudo systemctl start vtadmin-api
sudo systemctl status vtadmin-api
sudo systemctl start vtadmin-web
sudo systemctl status vtadmin-web
```

Last but not lease we will enable all the services so they will start on boot if we need to reboot the machine.

```
sudo systemctl enable vtctld
sudo systemctl enable vtadmin-api
sudo systemctl enable vtadmin-web
sudo systemctl enable vtorc
sudo systemctl enable vtgate
sudo systemctl enable mysql1
sudo systemctl enable mysql1-vtab
sudo systemctl enable mysql2
sudo systemctl enable mysql2-vtab
sudo systemctl enable mysql3
sudo systemctl enable mysql3-vtab
```

## Appendix

If we already have a cluster we can set the durability policy on that keyspace.

```
vtctldclient --server localhost:15999 SetKeyspaceDurabilityPolicy --durability-policy=semi_sync commerce
```

If the database does not become primary then we can switch of the read only mode and create the vt_commerce database manually. Not recommended but have worked for me in the past.

```
SET GLOBAL read_only = OFF; 
SELECT @@global.read_only;
```

If we need to reset and want to remove the keyspace this is done in the command line interface. The shard can easily be removed from the admin interface but this command will remove an empty keyspace.

```
vtctldclient --server localhost:15999 DeleteKeyspace -r commerce
```

First we setup our path so we have the commands available.

```
echo "export PATH=/usr/local/vitess/bin:${PATH}" >> ~/.profile
source ~/.profile 
```
