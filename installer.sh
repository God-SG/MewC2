#!/bin/bash
chmod 777 ***
# Display ASCII art
printf "\x1b[47m                                       \x1b[0m\n"
printf "\x1b[47m                                       \x1b[0m\n"
printf "\x1b[47m                                       \x1b[0m\n"
printf "\x1b[44m                                       \x1b[0m\n"
printf "\x1b[44m           Slovakia Reborn             \x1b[0m\n"
printf "\x1b[44m                                       \x1b[0m\n"
printf "\x1b[41m                                       \x1b[0m\n"
printf "\x1b[41m                                       \x1b[0m\n"
printf "\x1b[41m                                       \x1b[0m\n"

printf "\n\e[1;36mStarting Slovakia Dependency Installer...\e[0m\n"

printf "\e[1;33mUpdating system packages...\e[0m\n"
sudo apt update && sudo apt upgrade -y

printf "\e[1;32mInstalling 'screen' package...\e[0m\n"
sudo apt install screen -y

printf "\n\e[1;35mInstallation complete!\e[0m\n"
printf "\e[1;34mYou can now safely delete the 'installer.sh' file.\e[0m\n"
printf "\e[1;36mNavigate to the following files to configure your IP and Port:\e[0m\n"
printf "\e[1;32m- Slovakia/assets/configs/slovakia.toml\e[0m\n"
printf "\e[1;32m- Slovakia/assets/configs/web.toml\e[0m\n"