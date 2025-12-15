#!/bin/bash

# Ensure TERM is set to a valid value
export TERM=${TERM:-xterm-256color}

WIDTH=$(tput cols)
HEIGHT=$(tput lines)

MARGIN_LEFT=1
MARGIN_RIGHT=$((WIDTH - 1 - MARGIN_LEFT))
MARGIN_TOP=1
MARGIN_BOTTOM=$((HEIGHT - 1 - MARGIN_TOP))

BALL_X=$((WIDTH / 2))
BALL_Y=$((HEIGHT / 2))

DELTA_X=1
DELTA_Y=1

BAT_Y=$BALL_Y
PREV_BAT_Y=$BAT_Y
BAT_SIZE=$((HEIGHT / 5 + 1))

CLEAR_POINTS=()

SCORE=0

init() {
    clear

    tput civis

    stty -echo -icanon time 0 min 0
}

quit() {
    tput clear
    tput cvvis
    stty sane
    exit
}

centered_text() {
    length=${#1}
    tput cup $((HEIGHT / 2)) $((WIDTH / 2 - length / 2))
    echo -n "$1"
}

welcome() {
    tput clear
    centered_text "Welcome to Pong!"
    sleep .7
    tput clear
    centered_text "Starting Game In..."
    sleep .7
    tput clear
    for i in 3 2 1; do
        centered_text "$i"
        sleep .7
        tput clear
    done
    tput clear
}

game_over() {
    tput clear
    centered_text "Game Over!"
    sleep .7
    centered_text "You Scored $((SCORE / 2)) Points!"
    sleep .7
    quit
}

draw_at() {
    tput cup "$1" "$2"
    echo -n "$3"
}

clear_screen() {
    if [[ "$PREV_BAT_Y" -eq "$BAT_Y" ]]
    then
        draw_at ${CLEAR_POINTS[0]} ' '
        return
    elif [[ "$PREV_BAT_Y" -lt "$BAT_Y" ]]
    then
        unset CLEAR_POINTS[2]
        unset CLEAR_POINTS[4]
    else
        unset CLEAR_POINTS[1]
        unset CLEAR_POINTS[3]
    fi

    for point in "${CLEAR_POINTS[@]}"
    do
        draw_at $point ' '
    done
}

remember_points() {
        CLEAR_POINTS=(
            "$BALL_Y $BALL_X"
            "$BAT_START $MARGIN_LEFT"
            "$BAT_END $MARGIN_LEFT"
            "$BAT_START $MARGIN_RIGHT"
            "$BAT_END $MARGIN_RIGHT"
        )
}

draw() {
    clear_screen

    draw_at $BALL_Y $BALL_X 'O'
    BAT_START=$((BAT_Y - BAT_SIZE / 2))
    BAT_END=$((BAT_START + BAT_SIZE))
    for i in $(seq $BAT_START $BAT_END)
    do
        draw_at "$i" $MARGIN_LEFT '┃'
        draw_at "$i" $MARGIN_RIGHT '┃'
    done

    remember_points
}

handle_input() {
    PREV_BAT_Y="$BAT_Y"

    case "$(cat --show-nonprinting)" in
        '^[[A'|k)
            (( BAT_START > MARGIN_TOP && BAT_Y-- ))
            ;;
        '^[[B'|j)
            (( BAT_END < MARGIN_BOTTOM && BAT_Y++ ))
            ;;
        q)
            quit
            ;;
        *)
            ;;
    esac
}

caught_by_bat() {
    (( BALL_Y > BAT_START - 1 && BALL_Y < BAT_END + 1 ))
}

update_ball() {
    (( BALL_X < MARGIN_LEFT - 1 || BALL_X > MARGIN_RIGHT + 1 )) && game_over
    if (( BALL_X >= MARGIN_RIGHT - 1 ))
    then
        if caught_by_bat
        then
            DELTA_X=-1
            SCORE=$((SCORE+1))
        else
            DELTA_X=1
        fi
    elif (( BALL_X <= MARGIN_LEFT + 1 ))
    then
        if caught_by_bat
        then
            DELTA_X=1
            SCORE=$((SCORE+1))
        else
            DELTA_X=-1
        fi
    fi

    if (( BALL_Y >= MARGIN_BOTTOM ))
    then
        DELTA_Y=-1
    elif (( BALL_Y <= MARGIN_TOP ))
    then
        DELTA_Y=1
    fi

    (( BALL_Y += DELTA_Y ))
    (( BALL_X += DELTA_X ))
}

main_loop() {
    handle_input
    update_ball
    draw
    sleep 0.06
}

init
welcome

while :
do
    main_loop
done

quit