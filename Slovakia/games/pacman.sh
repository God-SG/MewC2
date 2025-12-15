#!/usr/bin/env bash

set -u

# Simple Pac-Man-inspired terminal game written in Bash.
# Controls: Arrow keys or WASD to move, Q to quit.
# Designed to run inside xterm; if not already in one, the script will
# prompt you to start xterm for proper key handling and rendering.

map_layout=(
"###################"
"#........#........#"
"#.###.###.#.###.###"
"#o###.#.#.#.#.#.###"
"#.###.#.#.#.#.#.o.#"
"#.....#...P...#...#"
"###.#.#.#####.#.#.#"
"#...#...G#G...#...#"
"#.###.###.#.###.###"
"#o................."
"###################"
)

grid=()
pacman_x=0
pacman_y=0
pacman_start_x=0
pacman_start_y=0
pacman_dir=">"
score=0
lives=3
pellets_remaining=0
power_timer=0
alt_screen_active=0

COLOR_RESET=$'\033[0m'
COLOR_WALL=$(tput setaf 4 2>/dev/null || printf '\033[34m')
COLOR_PELLET=$(tput setaf 7 2>/dev/null || printf '\033[37m')
COLOR_POWER=$(tput setaf 5 2>/dev/null || printf '\033[35m')
COLOR_PACMAN=$(tput setaf 3 2>/dev/null || printf '\033[33m')
COLOR_GHOST=$(tput setaf 1 2>/dev/null || printf '\033[31m')
COLOR_FRIGHT=$(tput setaf 6 2>/dev/null || printf '\033[36m')

declare -a ghost_x
declare -a ghost_y
declare -a ghost_home_x
declare -a ghost_home_y
declare -a ghost_dir

cleanup() {
  tput cnorm 2>/dev/null || true
  stty echo icanon 2>/dev/null || true
  [[ ${alt_screen_active:-0} -eq 1 ]] && { tput rmcup 2>/dev/null || true; alt_screen_active=0; }
  printf "\033[?25h" 2>/dev/null || true
}

trap cleanup EXIT

ensure_xterm() {
  if [[ ${PACMAN_XTERM:-0} -eq 1 ]]; then
    return
  fi

  if [[ ${TERM:-} != xterm* ]]; then
    if command -v xterm >/dev/null 2>&1; then
      echo "Pacman runs best in xterm. Launching xterm..." >&2
      PACMAN_XTERM=1 exec xterm -title "Pacman (Bash)" -geometry 90x30 -fa monospace -fs 12 \
        -e bash -lc "cd -- '$(pwd)' && TERM=xterm-256color PACMAN_XTERM=1 '$0'"
    else
      echo "Please run this script in xterm (or set TERM=xterm) for full compatibility." >&2
      sleep 1
    fi
  fi
}

get_cell() {
  local y=$1 x=$2
  printf '%s' "${grid[$y]:$x:1}"
}

set_cell() {
  local y=$1 x=$2 value=$3
  grid[$y]="${grid[$y]:0:$x}${value}${grid[$y]:$((x + 1))}"
}

overlay_char() {
  local row=$1 x=$2 char=$3
  printf '%s' "${row:0:$x}${char}${row:$((x + 1))}"
}

colorize_row() {
  local row=$1
  local colored=""
  local char color
  for (( i=0; i<${#row}; i++ )); do
    char=${row:$i:1}
    case "$char" in
      '#') color=$COLOR_WALL ;;
      '.') color=$COLOR_PELLET ;;
      'o') color=$COLOR_POWER ;;
      '>'|'<') color=$COLOR_PACMAN ;;
      '^'|'v') color=$COLOR_PACMAN ;;
      'M') color=$COLOR_GHOST ;;
      'm') color=$COLOR_FRIGHT ;;
      *) color="$COLOR_RESET" ;;
    esac
    colored+="${color}${char}${COLOR_RESET}"
  done
  printf '%b\n' "$colored"
}

parse_map() {
  grid=()
  ghost_x=()
  ghost_y=()
  ghost_home_x=()
  ghost_home_y=()
  ghost_dir=()
  pellets_remaining=0
  local y=0
  for row in "${map_layout[@]}"; do
    local processed_row=$row
    local x=0
    while (( x < ${#row} )); do
      local tile=${row:$x:1}
      case "$tile" in
        P)
          pacman_start_x=$x
          pacman_start_y=$y
          pacman_x=$x
          pacman_y=$y
          processed_row="${processed_row:0:$x}.${processed_row:$((x + 1))}"
          ((pellets_remaining++))
          ;;
        G)
          ghost_x+=($x)
          ghost_y+=($y)
          ghost_home_x+=($x)
          ghost_home_y+=($y)
          ghost_dir+=(left)
          processed_row="${processed_row:0:$x} ${processed_row:$((x + 1))}"
          ;;
        .|o)
          ((pellets_remaining++))
          ;;
      esac
      ((x++))
    done
    grid+=("$processed_row")
    ((y++))
  done
}

in_bounds() {
  local x=$1 y=$2
  (( y >= 0 && y < ${#grid[@]} && x >= 0 && x < ${#grid[0]} ))
}

cell_is_wall() {
  [[ $(get_cell "$2" "$1") == "#" ]]
}

next_position() {
  local x=$1 y=$2 direction=$3
  case "$direction" in
    up) ((y--)); pacman_dir="^" ;;
    down) ((y++)); pacman_dir="v" ;;
    left) ((x--)); pacman_dir="<" ;;
    right) ((x++)); pacman_dir=">" ;;
  esac
  printf '%s %s' "$x" "$y"
}

wrap_position() {
  local x=$1 y=$2 width=${#grid[0]} height=${#grid[@]}
  (( x < 0 )) && x=$((width - 1))
  (( x >= width )) && x=0
  (( y < 0 )) && y=$((height - 1))
  (( y >= height )) && y=0
  printf '%s %s' "$x" "$y"
}

update_pacman() {
  local key=$1
  local direction=""
  case "$key" in
    w|W|A) direction=up ;;
    s|S|B) direction=down ;;
    a|A|D) direction=left ;;
    d|D|C) direction=right ;;
    *) return ;;
  esac

  read -r new_x new_y <<<"$(next_position "$pacman_x" "$pacman_y" "$direction")"
  read -r new_x new_y <<<"$(wrap_position "$new_x" "$new_y")"

  if cell_is_wall "$new_x" "$new_y"; then
    return
  fi

  local tile=$(get_cell "$new_y" "$new_x")
  case "$tile" in
    .)
      ((score += 10))
      ((pellets_remaining--))
      set_cell "$new_y" "$new_x" " "
      ;;
    o)
      ((score += 50))
      ((pellets_remaining--))
      power_timer=60
      set_cell "$new_y" "$new_x" " "
      ;;
  esac

  pacman_x=$new_x
  pacman_y=$new_y
}

valid_moves() {
  local x=$1 y=$2
  local dirs=()
  read -r nx ny <<<"$(wrap_position "$x" "$((y - 1))")"
  [[ $(get_cell "$ny" "$nx") != "#" ]] && dirs+=(up)

  read -r nx ny <<<"$(wrap_position "$x" "$((y + 1))")"
  [[ $(get_cell "$ny" "$nx") != "#" ]] && dirs+=(down)

  read -r nx ny <<<"$(wrap_position "$((x - 1))" "$y")"
  [[ $(get_cell "$ny" "$nx") != "#" ]] && dirs+=(left)

  read -r nx ny <<<"$(wrap_position "$((x + 1))" "$y")"
  [[ $(get_cell "$ny" "$nx") != "#" ]] && dirs+=(right)

  printf '%s\n' "${dirs[@]}"
}

random_direction() {
  local options=("$@")
  local count=${#options[@]}
  (( count == 0 )) && return
  printf '%s' "${options[RANDOM % count]}"
}

move_ghosts() {
  local i=0
  for i in "${!ghost_x[@]}"; do
    local gx=${ghost_x[$i]}
    local gy=${ghost_y[$i]}
    local preferred=${ghost_dir[$i]}

    mapfile -t moves < <(valid_moves "$gx" "$gy")
    # remove empty entries
    local filtered=()
    for m in "${moves[@]}"; do
      [[ -n "$m" ]] && filtered+=("$m")
    done

    local chosen=$preferred
    local can_continue=false
    for m in "${filtered[@]}"; do
      if [[ "$m" == "$preferred" ]]; then
        can_continue=true
        break
      fi
    done

    if [[ ${#filtered[@]} -eq 0 ]]; then
      continue
    elif [[ "$can_continue" != true ]]; then
      chosen=$(random_direction "${filtered[@]}")
    elif (( RANDOM % 5 == 0 )); then
      chosen=$(random_direction "${filtered[@]}")
    fi

    ghost_dir[$i]="$chosen"
    read -r gx gy <<<"$(next_position "$gx" "$gy" "$chosen")"
    read -r gx gy <<<"$(wrap_position "$gx" "$gy")"
    if cell_is_wall "$gx" "$gy"; then
      continue
    fi

    ghost_x[$i]=$gx
    ghost_y[$i]=$gy

    if (( gx == pacman_x && gy == pacman_y )); then
      if (( power_timer > 0 )); then
        ((score += 200))
        ghost_x[$i]=${ghost_home_x[$i]}
        ghost_y[$i]=${ghost_home_y[$i]}
        ghost_dir[$i]=left
      else
        lose_life
        return
      fi
    fi
  done
}

lose_life() {
  ((lives--))
  pacman_x=$pacman_start_x
  pacman_y=$pacman_start_y
  power_timer=0
  for i in "${!ghost_x[@]}"; do
    ghost_x[$i]=${ghost_home_x[$i]}
    ghost_y[$i]=${ghost_home_y[$i]}
    ghost_dir[$i]=left
  done
  if (( lives <= 0 )); then
    game_over
  fi
}

draw_board() {
  printf "\033[H\033[2J"
  printf "%sScore:%s %s%d%s  %sLives:%s %s%d%s  %sPellets:%s %s%d%s  %s%s\n" \
    "$COLOR_PELLET" "$COLOR_RESET" "$COLOR_PELLET" "$score" "$COLOR_RESET" \
    "$COLOR_POWER" "$COLOR_RESET" "$COLOR_POWER" "$lives" "$COLOR_RESET" \
    "$COLOR_WALL" "$COLOR_RESET" "$COLOR_WALL" "$pellets_remaining" "$COLOR_RESET" \
    "$COLOR_POWER" "$( ((power_timer>0)) && printf 'Power:%2d ' "$power_timer" )" "$COLOR_RESET"
  for (( y=0; y<${#grid[@]}; y++ )); do
    local row=${grid[$y]}
    if (( pacman_y == y )); then
      row=$(overlay_char "$row" "$pacman_x" "$pacman_dir")
    fi
    for i in "${!ghost_x[@]}"; do
      if (( ghost_y[$i] == y )); then
        local ghost_char="M"
        (( power_timer > 0 )) && ghost_char="m"
        row=$(overlay_char "$row" "${ghost_x[$i]}" "$ghost_char")
      fi
    done
    colorize_row "$row"
  done
  echo "Controls: Arrow keys or WASD to move, Q to quit."
}

game_over() {
  draw_board
  echo "Game over! Final score: $score"
  exit 0
}

check_collision() {
  for i in "${!ghost_x[@]}"; do
    if (( ghost_x[$i] == pacman_x && ghost_y[$i] == pacman_y )); then
      if (( power_timer > 0 )); then
        ((score += 200))
        ghost_x[$i]=${ghost_home_x[$i]}
        ghost_y[$i]=${ghost_home_y[$i]}
        ghost_dir[$i]=left
      else
        lose_life
      fi
    fi
  done
}

read_key() {
  local key
  if IFS= read -rsn1 -t 0.08 key; then
    if [[ $key == $'\e' ]]; then
      if read -rsn2 -t 0.001 key; then
        case "$key" in
          "[A") key=A ;;
          "[B") key=B ;;
          "[C") key=C ;;
          "[D") key=D ;;
        esac
      fi
    fi
    echo "$key"
  fi
}

main_loop() {
  ensure_xterm
  stty -echo -icanon time 0 min 0 2>/dev/null || true
  tput smcup 2>/dev/null && alt_screen_active=1
  tput civis 2>/dev/null || printf "\033[?25l" 2>/dev/null
  parse_map

  while true; do
    draw_board
    (( pellets_remaining <= 0 )) && { echo "You win! Final score: $score"; break; }
    (( power_timer > 0 )) && ((power_timer--))

    local key="$(read_key)"
    if [[ ${key,,} == q ]]; then
      echo "Thanks for playing!"; break
    fi

    [[ -n "$key" ]] && update_pacman "$key"
    check_collision
    move_ghosts
    check_collision
  done
}

main_loop