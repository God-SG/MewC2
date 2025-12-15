#!/usr/bin/env bash
# Centipede - 256-color xterm, flicker-free, corrected colors
# Save as centipede.sh, chmod +x centipede.sh, run in xterm -e ./centipede.sh

# ==== CONFIG ====
FRAME_DELAY=0.06
SAFE_MARGIN=2
MAX_MUSHROOMS=60
INITIAL_CENTI_LEN=12
BASE_CENTI_SPEED_FRAMES=4
SHOTS_LIMIT=4
MUSH_HP_MAX=3

# ==== Colors ====
C_HEAD=82
C_PLAYER=51
C_SHOT=15
C_BORDER=226
C_EXPLO=196
MUSH_COL_HP3=201
MUSH_COL_HP2=166
MUSH_COL_HP1=220
RAINBOW=(196 202 226 46 51 21 93)

RESET="$(printf "\033[0m")"

# ==== Characters ====
PLAYER_CH="A"
SHOT_CH="|"
MUSH_CH="#"
CENTI_HEAD_CH="O"
CENTI_BODY_CH="o"
EXPLO_CH="*"
BORDER_H="-"
BORDER_V="¦"

# ==== Terminal housekeeping ====
cleanup() {
    tput cnorm
    stty "$ORIG_STTY"
    printf "\033[2J\033[H"
    exit 0
}
trap cleanup INT TERM EXIT
ORIG_STTY=$(stty -g)
stty -icanon -echo min 0 time 0
tput civis

# ==== Terminal size & play area ====
WIDTH=$(tput cols)
HEIGHT=$(tput lines)
PLAY_W=$((WIDTH - SAFE_MARGIN))
PLAY_H=$((HEIGHT - 4))
((PLAY_W<40 || PLAY_H<15)) && { echo "Terminal too small"; cleanup; }

# ==== Game state arrays ====
declare -a mushrooms_x mushrooms_y mushrooms_hp
declare -a shots_x shots_y shots_alive prev_shots_x prev_shots_y
declare -a centi_x centi_y centi_dir prev_centi_x prev_centi_y

player_x=$((PLAY_W / 2))
player_y=$PLAY_H
score=0
lives=3
wave=1
frame=0
centi_move_counter=0

# ==== Helpers ====
draw_at() { printf "\033[%d;%dH%s" "$1" "$2" "$3"; }
cseq() { printf "\033[38;5;%dm" "$1"; }

mush_color_for_hp() {
    case $1 in
        3) echo $MUSH_COL_HP3 ;;
        2) echo $MUSH_COL_HP2 ;;
        1) echo $MUSH_COL_HP1 ;;
        *) echo 15 ;;
    esac
}

# ==== Title Screen ====
show_title() {
    clear
    local cx=$((PLAY_W / 2))
    local cy=$((PLAY_H / 2 - 5))
    draw_at $((cy-2)) $((cx-20)) "$(cseq 93)\033[1m=== CENTIPEDE (BASH) ===$RESET"
    draw_at $((cy+0)) $((cx-30)) "Controls: a/d or ?/? move    space/s shoot    q quit"
    draw_at $((cy+2)) $((cx-26)) "Mushrooms take ${MUSH_HP_MAX} hits (colors show damage)."
    draw_at $((cy+4)) $((cx-12)) "Press any key to start..."
    stty -icanon -echo
    read -rsn1
    stty -icanon -echo min 0 time 0
    clear
}

# ==== Initialize Mushrooms and Centipede ====
init_mushrooms() {
    mushrooms_x=(); mushrooms_y=(); mushrooms_hp=()
    for ((i=0;i<MAX_MUSHROOMS;i++)); do
        mushrooms_x+=($(( (RANDOM % (PLAY_W - 6)) + 3 )))
        mushrooms_y+=($(( (RANDOM % (PLAY_H - 6)) + 2 )))
        mushrooms_hp+=($MUSH_HP_MAX)
    done
}

init_centipede() {
    centi_x=(); centi_y=(); centi_dir=()
    local len=$(( INITIAL_CENTI_LEN + wave - 1 ))
    for ((i=0;i<len;i++)); do
        centi_x[$i]=$((2 + i))
        centi_y[$i]=2
        centi_dir[$i]=1
    done
    prev_centi_x=("${centi_x[@]}")
    prev_centi_y=("${centi_y[@]}")
}

draw_border_once() {
    for ((x=1;x<=PLAY_W;x++)); do
        draw_at 1 $x "$(cseq $C_BORDER)$BORDER_H$RESET"
        draw_at $((PLAY_H+1)) $x "$(cseq $C_BORDER)$BORDER_H$RESET"
    done
    for ((y=1;y<=PLAY_H+1;y++)); do
        draw_at $y 1 "$(cseq $C_BORDER)$BORDER_V$RESET"
        draw_at $y $PLAY_W "$(cseq $C_BORDER)$BORDER_V$RESET"
    done
}

draw_info() {
    draw_at $((PLAY_H+3)) 2 "$(cseq 51)Score:$RESET $(cseq 15)$score$RESET    $(cseq 226)Lives:$RESET $(cseq 15)$lives$RESET    $(cseq 201)Wave:$RESET $(cseq 15)$wave$RESET"
    draw_at $((PLAY_H+4)) 2 "$(cseq 93)Controls:$RESET a/d or ?/?  space/s shoot  q quit"
}

# ==== Input Handling ====
read_input() {
    local key
    IFS= read -rsn1 -t 0.001 key || return
    [[ "$key" == $'\x1b' ]] && { IFS= read -rsn2 -t 0.001 seq || seq=""; key+="$seq"; }
    case "$key" in
        a|A|$'\x1b[D') ((player_x>2)) && ((player_x--)) ;;
        d|D|$'\x1b[C') ((player_x<PLAY_W-1)) && ((player_x++)) ;;
        " "|s|S) shoot ;;
        q|Q) cleanup ;;
    esac
}

shoot() {
    (( ${#shots_x[@]} >= SHOTS_LIMIT )) && return
    shots_x+=("$player_x")
    shots_y+=($((player_y-1)))
    shots_alive+=(1)
}

update_shots() {
    local nx=() ny=() na=()
    for ((i=0;i<${#shots_x[@]};i++)); do
        (( shots_alive[i]==0 )) && continue
        local sx=${shots_x[i]} sy=$((shots_y[i]-1))
        (( sy<=1 )) && continue
        local hit=0
        for ((m=0;m<${#mushrooms_x[@]};m++)); do
            if (( mushrooms_x[m]==sx && mushrooms_y[m]==sy )); then
                mushrooms_hp[m]=$(( mushrooms_hp[m]-1 ))
                if (( mushrooms_hp[m]<=0 )); then
                    unset 'mushrooms_x[m]' 'mushrooms_y[m]' 'mushrooms_hp[m]'
                    mushrooms_x=("${mushrooms_x[@]}"); mushrooms_y=("${mushrooms_y[@]}"); mushrooms_hp=("${mushrooms_hp[@]}")
                    score=$(( score+10 ))
                else
                    score=$(( score+3 ))
                fi
                hit=1; break
            fi
        done
        (( hit )) && continue
        for ((c=0;c<${#centi_x[@]};c++)); do
            if (( centi_x[c]==sx && centi_y[c]==sy )); then
                spawn_mushroom_at "$sx" "$sy" "$MUSH_HP_MAX"
                unset 'centi_x[c]' 'centi_y[c]' 'centi_dir[c]'
                centi_x=("${centi_x[@]}"); centi_y=("${centi_y[@]}"); centi_dir=("${centi_dir[@]}")
                score=$(( score+50 )); hit=1; break
            fi
        done
        (( hit )) && continue
        nx+=("$sx"); ny+=("$sy"); na+=(1)
    done
    prev_shots_x=("${shots_x[@]}"); prev_shots_y=("${shots_y[@]}")
    shots_x=("${nx[@]}"); shots_y=("${ny[@]}"); shots_alive=("${na[@]}")
}

spawn_mushroom_at() {
    local mx=$1 my=$2 mh=${3:-$MUSH_HP_MAX}
    (( mx==player_x && my==player_y )) && return
    mushrooms_x+=("$mx"); mushrooms_y+=("$my"); mushrooms_hp+=("$mh")
}

# ==== Centipede movement ====
centi_speed_frames() {
    local val=$(( BASE_CENTI_SPEED_FRAMES - (wave-1)/2 )); ((val<1)) && val=1
    echo $val
}

move_centipede() {
    (( ${#centi_x[@]}==0 )) && return
    local len=${#centi_x[@]}
    local new_x=() new_y=() new_d=()
    local hx=${centi_x[0]} hy=${centi_y[0]} dir=${centi_dir[0]}
    local nx=$((hx+dir)) ny=$hy
    local blocked=0
    (( nx<=1 || nx>=PLAY_W )) && blocked=1
    for ((m=0;m<${#mushrooms_x[@]};m++)); do (( mushrooms_x[m]==nx && mushrooms_y[m]==ny )) && blocked=1; done
    (( blocked )) && { ny=$((hy+1)); dir=$(( -dir )); nx=$hx; }
    new_x[0]=$nx; new_y[0]=$ny; new_d[0]=$dir
    for ((i=1;i<len;i++)); do
        new_x[i]=${centi_x[i-1]}; new_y[i]=${centi_y[i-1]}; new_d[i]=${centi_dir[i-1]}
    done
    prev_centi_x=("${centi_x[@]}"); prev_centi_y=("${centi_y[@]}")
    centi_x=("${new_x[@]}"); centi_y=("${new_y[@]}"); centi_dir=("${new_d[@]}")
}

explode_player() {
    draw_at "$player_y" "$player_x" "$(cseq $C_EXPLO)\033[1m$EXPLO_CH$RESET"
    sleep 0.12; lives=$((lives-1)); score=$((score-100))
    (( lives<=0 )) && game_over
    player_x=$(( PLAY_W/2 ))
}

check_collisions() {
    for ((i=0;i<${#centi_x[@]};i++)); do
        (( centi_x[i]==player_x && centi_y[i]==player_y )) && { explode_player; unset 'centi_x[i]' 'centi_y[i]' 'centi_dir[i]'; centi_x=("${centi_x[@]}"); centi_y=("${centi_y[@]}"); centi_dir=("${centi_dir[@]}"); break; }
    done
}

game_over() {
    clear
    draw_at $((PLAY_H/2)) $((PLAY_W/2-6)) "$(cseq 196)\033[1mGAME OVER$RESET"
    draw_at $((PLAY_H/2+1)) $((PLAY_W/2-12)) "Final Score: $score    Press any key to exit."
    stty -icanon -echo
    read -rsn1 -t 10 || true
    cleanup
}

# ==== Render Incrementally ====
render() {
    # Mushrooms
    for ((i=0;i<${#mushrooms_x[@]};i++)); do
        draw_at "${mushrooms_y[i]}" "${mushrooms_x[i]}" "$(cseq $(mush_color_for_hp ${mushrooms_hp[i]}))$MUSH_CH$RESET"
    done
    # Centipede: erase previous
    for ((i=0;i<${#prev_centi_x[@]};i++)); do
        draw_at "${prev_centi_y[i]}" "${prev_centi_x[i]}" " "
    done
    # Draw centipede
    for ((i=0;i<${#centi_x[@]};i++)); do
        local sx=${centi_x[i]} sy=${centi_y[i]}
        (( i==0 )) && draw_at "$sy" "$sx" "$(cseq $C_HEAD)\033[1m$CENTI_HEAD_CH$RESET" || draw_at "$sy" "$sx" "$(cseq ${RAINBOW[$(( (i-1)%${#RAINBOW[@]} ))]})$CENTI_BODY_CH$RESET"
    done
    # Shots: erase previous
    for ((i=0;i<${#prev_shots_x[@]};i++)); do
        draw_at "${prev_shots_y[i]}" "${prev_shots_x[i]}" " "
    done
    prev_shots_x=("${shots_x[@]}"); prev_shots_y=("${shots_y[@]}")
    for ((i=0;i<${#shots_x[@]};i++)); do
        (( shots_alive[i]==1 )) && draw_at "${shots_y[i]}" "${shots_x[i]}" "$(cseq $C_SHOT)$SHOT_CH$RESET"
    done
    # Player
    draw_at "$player_y" "$player_x" "$(cseq $C_PLAYER)\033[1m$PLAYER_CH$RESET"
    draw_info
}

# ==== Main Loop ====
show_title
draw_border_once
init_mushrooms
init_centipede
shots_x=() shots_y=() shots_alive=()
CENTI_SPEED_FRAMES=$(centi_speed_frames)

while true; do
    frame=$((frame+1))
    read_input
    update_shots
    CENTI_SPEED_FRAMES=$(centi_speed_frames)
    centi_move_counter=$((centi_move_counter+1))
    (( centi_move_counter >= CENTI_SPEED_FRAMES )) && { centi_move_counter=0; move_centipede; }
    check_collisions
    (( RANDOM%200==0 )) && spawn_mushroom_at $(( (RANDOM%(PLAY_W-6))+3 )) $(( (RANDOM%(PLAY_H-6))+2 )) $MUSH_HP_MAX
    (( ${#centi_x[@]}==0 )) && { score=$((score+500)); wave=$((wave+1)); for i in $(seq 1 6); do render; sleep 0.06; done; for i in $(seq 1 6); do spawn_mushroom_at $(( (RANDOM%(PLAY_W-6))+3 )) $(( (RANDOM%(PLAY_H-6))+2 )) $MUSH_HP_MAX; done; init_centipede; }
    render
    sleep "$FRAME_DELAY"
done
