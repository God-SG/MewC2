#!/bin/bash

# HANGMAN - 80x24 terminal version
# Author: Ashton Seth Reimer (Modified by ChatGPT)
# Requires: dict.dat in the same directory

# Initialize arrays
declare -a word
declare -a word_img
declare -a alpha_img
alpha=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
char=""
i=0

function readfile {
  word=(
    apple banana orange grape peach cherry mango lemon kiwi melon berry
    tomato potato onion carrot lettuce cucumber pepper garlic broccoli cabbage spinach radish celery squash turnip zucchini parsley basil
    zebra horse tiger lion leopard cheetah bear wolf fox giraffe koala monkey gorilla panda elephant rhino hippo kangaroo llama deer moose
    dolphin whale shark octopus squid turtle seal otter crab lobster salmon tuna goldfish
    tree forest river ocean lake mountain desert canyon valley volcano island glacier hill bay waterfall
    rain storm thunder lightning snow wind tornado hurricane cloud sun moon star sky eclipse sunrise sunset
    red blue green yellow purple orange black white brown gray pink cyan indigo violet teal maroon beige gold silver bronze
    python bash linux ubuntu debian fedora windows macos terminal script keyboard monitor mouse laptop tablet phone server router modem
    rocket engine spaceship astronaut galaxy planet star solar comet meteor asteroid satellite orbit telescope
    pizza burger taco sandwich spaghetti lasagna sushi ramen dumpling steak bacon sausage toast pancake waffle cereal muffin donut croissant
    castle tower bridge gate wall dungeon fortress moat throne crown sword shield armor knight dragon wizard potion scroll wand rune
    pencil paper eraser marker chalk notebook binder folder ruler compass protractor calculator blackboard clipboard desk chair locker
    soccer baseball football tennis hockey basketball golf cricket boxing swimming running cycling gymnastics fencing skiing snowboarding
    school student teacher homework exam test quiz lesson grade report diploma certificate campus uniform schedule subject backpack
    circle square triangle rectangle polygon diamond hexagon octagon cube sphere cone cylinder pyramid prism fractal
    music guitar piano drums trumpet violin saxophone flute clarinet cello accordion harp microphone speaker headphones concert orchestra band
    love peace joy hope trust faith honor pride courage kindness patience respect freedom justice unity truth
    travel journey vacation adventure explore wander discover escape visit climb hike sail fly drive camp tour
    idea dream thought memory emotion feeling reason logic belief vision plan goal wish choice chance
    energy gravity magnet laser plasma atom molecule element neutron proton electron nucleus quantum theory force wave
  )
  i=${#word[@]}
}

function readword {
  word_index=$((RANDOM % i))
  word_img=()
  for ((a=0; a<${#word[$word_index]}; a++)); do
    word_img[a]=0
  done
}

function gallows {
  clear
  case $incorrect in
    0) draw_gallows "" "" "" ;;
    1) draw_gallows "(_)" "" "" ;;
    2) draw_gallows "(_)" " | " "" ;;
    3) draw_gallows "(_)" "/| " "" ;;
    4) draw_gallows "(_)" "/|\\" "" ;;
    5) draw_gallows "(_)" "/|\\" "/  " ;;
    6) draw_gallows "(_)" "/|\\" "/ \\" ;;
  esac
}

function draw_gallows {
  echo "  ________"
  echo "  |/     |"
  printf "  |     %-5s\n" "$1"
  printf "  |     %-5s\n" "$2"
  printf "  |     %-5s\n" "$3"
  echo "  |"
  echo " _|_"
}

function guess {
  correct=0
echo
echo -n "Guess a letter: "

  read guess
  guess=${guess,,}
  char="$guess"

  if [[ ${#guess} -eq 1 ]]; then
    for ((j=0; j<${#word[$word_index]}; j++)); do
      if [[ "$guess" == "${word[$word_index]:j:1}" ]]; then
        word_img[j]=1
        correct=1
      fi
    done
  fi

  numletter=0
  for val in "${word_img[@]}"; do
    numletter=$((numletter + val))
  done
}

function print_alpha {
  echo -e "\nLetters Guessed:"
  for idx in {0..25}; do
    [[ "$char" == "${alpha[$idx]}" ]] && alpha_img[$idx]=1
    [[ "${alpha_img[$idx]}" == "1" ]] && echo -n "${alpha[$idx]} " || echo -n "_ "
    [[ $(( (idx+1)%13 )) -eq 0 ]] && echo
  done
  echo
  char=""
}

function print_word {
  echo
  echo -n "Word: "
  for (( t=0; t<${#word[$word_index]}; t++ )); do
    [[ "${word_img[$t]}" == "1" ]] && echo -n "${word[$word_index]:$t:1} " || echo -n "_ "
  done
  echo
}

function win {
  echo -e "\nYou won!\n"
}

function lose {
  echo -e "\nYou lost! The word was: ${word[$word_index]} 💀\n"
}

# Start game
readfile
while true; do
  gameover=0
  incorrect=0
  correct=0
  alpha_img=()
  readword

  while [[ $gameover -eq 0 ]]; do
    gallows
    print_alpha
    print_word
    guess

    [[ $correct -eq 0 ]] && incorrect=$((incorrect + 1))

    if [[ $numletter -eq ${#word[$word_index]} ]]; then
      gallows
      print_word
      win
      gameover=1
    elif [[ $incorrect -ge 6 ]]; then
      gallows
      lose
      gameover=1
    fi

    if [[ $gameover -eq 1 ]]; then
      echo -n "Play again? (y/n): "
      read answer
      [[ "$answer" == "y" ]] || break 2
    fi
  done
done

exit 0
