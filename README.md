# Slovakia Reborn

Thank you for choosing Slovakia Reborn, the premium solution for unparalleled customizability and flexibility.

# Setup Slovakia Reborn

Slovakia Reborn uses Sqlite as a database. This means you do not need to setup a database. 
Note there are some dependencies that would need to be installed. run the `installer.sh` file to
install these dependencies.

1. Upload `slovakia-reborn.rar` to your servers root directory and unrar the files onto your server.
2. Now run the following commmand in your root directory `/root/`: `chmod 777 *`
3. Then run: `chmod +x ./Slovakia/scripts/*`
4. Put your `license.sls` file that was shipped with your build into the `assets` directory.
5. Type `./run.sh`
6. Follow The Prompts

# Updating

When an update is released you'll be informed in the post on how to update the program.

# Login

1. Run Slovakia Reborn for the first time to let it build the database.
2. Open Putty or the terminal application.
3. On Putty:
   1. Set the host field to your server IP.
   2. Set the port field to your specified port. (What ever is in your `slovakia.toml`).
   3. Set Connect Type to "SSH".
   4. Click connect.
   5. Press enter to go to the custom login screen. ( Note: *Type redeem to see the redeem prompt for account redemption codes*)
5. Default username is `root`
6. You'll be given your first time login information upon startup. 
(This is located in the terminal output, type `screen -rx cnc` to see this or check the `default_user.txt` file that was created.)

# How to Backup Slovakia Reborn

Slovakia Reborn has a built in backup system that you can find options for in the `slovakia.toml` config file. 
Example:
[backup]
enabled=false
repeat_every_hours=24

The options here are self explanitory. The backup system will backup everything 
in your `assets` directory and store it in the `backup` directory.