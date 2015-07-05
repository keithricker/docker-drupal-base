# drupal-base
A lamp server for Drupal 7. Includes varnish and memcached. Key drupal components like composer and drush also included. Intended for use as a production web server. Mysql is not installed (intended for linking to separate database container). Optional ssh server.

####In Brief:

- Extends Phusion Base image (ubuntu), running Apache
- Compatible with Kalabox 2 (but not required)
- Optional SSH server
- Varnish is pre-configured (works out of the box)
- Solr Search Enabled
- Drush v6 enabled out of the box
- Sass and Compass enabled

####First things first:

You'll want to grab a mysql container and get that running. If you use my custom mysql container, then you will be able to get things up and running with minimal configuration and download time required, but you can use any available mysql or mariadb image.

####Fire up the Mysql Server

In order to enable access to the database, you'll need to have a port mapping from the host machine to the container's port 3306 ... so you will just need to add that as an extra parameter to the *"docker run"* command. As an example, we'll just use port 49158.

```

docker run -it --name database -p 49158:3306 -d kricker/mysql-base:latest

```

####If Using Boot2Docker:

Assuming you're running boot2docker on virtualbox, you'll need to do a little extra config, and give Vbox some ports to listen in on. You can do this manually via vbox settings, or you can run this in the command line. For this particular instance, we're just going to map port 49158 on our macbook to 49158 of the VM, and use that for our database connection:

```

VBoxManage modifyvm "boot2docker-vm" --natpf1 "mysql,tcp,,49158,,49158";

[restart boot2docker]

docker run --name database -p 49158:3306 -d kricker/mysql-base:latest

```

####Fire up the Drupal Server

If we want to work on our code locally without having to SSH in to anything, then we'll need to have a few directories we can share between our host machine and the container. For this particular example, we'll assume that our app's code will live in a directory aptly named "code," so that your project's directory on your host machine structure will be my-drupal-project/code/index.php or something along those lines. If you plan to use one of your existing D7 sites, then you'll just copy your code over to that directory.

The -v argument in the example run command below is used to map the "code" folder of your project's working directory (on your machine) to the Drupal container's web root folder.

In order for this to work with VM, your project will need to live somewhere within your "Home" path (i.e. ~/my-webapps/my-drupal-project or something along those lines).

#####*If you prefer to start from scratch, then leave the code folder completely bare, and the Drupal Base Image will install a fresh D7 site in that directory for you, with defaults:*

#####*Login ID="admin" and password="password"*

```
# From your project's directory, create a folder named "code" and run this script.
# If you want to use an existing drupal project, then copy that code to the code folder first -- then import your database after it runs. (See "Accessing the Database" below)

docker run -it --name drupalserver --link database:mysql -d -p 8080:80 -v $(pwd)/code:/srv/www/siteroot kricker/drupal-base:latest

```

Wait about 5 to 10 minutes for everything to download and install ... Open a web browser on your host machine and point it to port 8080 to view your welcome page:

```

http://localhost:8080

```


####Boot2Docker Instructions:

If running boot2docker, you will first need to create a port mapping so Vbox can listen in on port 8080 of your machine. 

You can do this in Vbox settings, or just run the following shell script and restart boot2docker :

```

VBoxManage modifyvm "boot2docker-vm" --natpf1 "tcp-port8080,tcp,,8080,,8080"

```

Now you should be able to run the *"docker run"* script above and http://localhost:8080 should bring up the welcome page.

####Accessing the Database

With the port mapping of 49158:3306 as outlined above ... the database can be accessed via command line, or using the mysql gui tool of your choice (I like sequel pro personally). Just use "localhost" as the host, and port 49158 (instead of the usual 3306). 

If used with *kricker/mysql-base*, then by default, there is a database set up named "mysite," with default user "root" and no password. 

These settings won't work with Kalabox without some extra config, so if you're using Kalabox, you should skip down to the instructions below.

```

host: 127.0.0.1
user: root
password:
database: mysite
port: 49158

```

####Enabling SSH

You can add ssh capability as an optional add-on. Just pass in "ENABLE_SSH" as an environment variable in the *docker run* command:

```

docker run -it --name drupalserver -p 8080:80 -p 49158:3306 -e "ENABLE_SSH=true" -d kricker/drupal-base:latest

```

####Using with Kalabox2

If you're using this image with Kalabox 2, then it is recommended that you run this in backdrop since that is all it has been tested with, but it should work with any of the others in theory, so it's worth a shot. I would recommend just rolling with all of the defaults in the kalabox.json file, and swap out the app server for this base image like so:

- Open the kalabox.json file in your backdrop app directory
- Under appserver > image > name, replace the image name with *kricker/drupal-base:latest* 

And all other steps for using Kalabox will apply, with the default database, etc. More instructions here:

https://github.com/kalabox/kalabox/wiki/Backdrop-Guide#user-content-import-your-database-optionaly

Note: If you aren't tied down or restricted to use of Apache and/or Ubuntu server, then there really aren't any notable advantages to running this base image over Kalabox's stock App Server, so you should probably just go with theirs if at all possible. This is just another option for those who either prefer an Apache/Ubuntu setup, or who are locked in to it for whatever reason.

