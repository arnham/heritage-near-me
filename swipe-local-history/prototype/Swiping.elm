module Swiping (animate, itemSwipe, itemPos, swipeActions, swipeAction, onSwipe, animateStep) where

import Json.Decode as Json exposing ((:=))
import Html exposing (Attribute)
import Html.Events exposing (on)
import Time exposing (Time)
import Easing exposing (..)
import Swipe exposing (..)

import Types exposing (..)

animate : Signal (Action id a)
animate = Signal.map AnimateItem timeSoFar

animateStep : Time -> ItemPosition -> ItemPosition
animateStep t state = case state of
    Leave pos -> Leaving pos t (t+600) t
    Return pos -> Returning pos t (t+600) t
    Leaving pos start end _ ->
        Leaving pos start end t
    Returning pos start end _ ->
        Returning pos start end t
    x -> x

sign : Float -> Float
sign number = abs number / number

timeSoFar : Signal Time
timeSoFar = Signal.foldp (+) 0 <| Time.fps 40

itemSwipe : ItemPosition -> Maybe SwipeState
itemSwipe pos = case pos of
    Types.Swiping swipe -> Just swipe
    _ -> Nothing

itemPos : ItemPosition -> Maybe Float
itemPos pos = case pos of
    Types.Swiping (Swipe.Swiping swipe) -> Just <| swipe.x1 - swipe.x0
    Leave pos -> Just pos
    Return pos -> Just pos
    Leaving pos start end t ->
        Just <| ease easeInCubic float pos (pos + (500*sign pos)) (end-start) (t-start)
    Returning pos start end t ->
        Just <| ease easeInCubic float pos 0 (end-start) (t-start)
    _ -> Nothing

swipeActions : Signal (Action id a)
swipeActions = Signal.map swipeAction swipes

swipeAction : Maybe SwipeState -> Action id a
swipeAction swipe = case swipe of
    Just (End state) ->
        if abs (state.x1 - state.x0) > 160 then
            MoveItem <| Leave <| state.x1 - state.x0
        else
            MoveItem <| Return <| state.x1 - state.x0
    Just swipe -> MoveItem <| Types.Swiping swipe
    Nothing -> NoAction
    
swipes : Signal (Maybe SwipeState)
swipes = Signal.map List.head swipeStates

onSwipe : Signal.Address a -> Maybe SwipeState -> (Maybe SwipeState -> a) -> List Attribute
onSwipe address swipeState swipeAction =
    let
        doAction touchState touchUpdate = Signal.message address
            <| swipeAction
            <| updateSwipeState swipeState touchState touchUpdate
    in
        [ on "touchstart" touch <| doAction TouchStart
        , on "touchmove" touch <| doAction TouchMove
        , on "touchend" touch <| doAction TouchEnd
        ]

updateSwipeState : Maybe SwipeState -> TouchState -> SwipeUpdate -> Maybe SwipeState
updateSwipeState swipe touch update = let
        dir x y = direction (update.x - x) (update.y - y)
    in
        case touch of
            TouchStart -> Just <| Start update
            TouchMove -> case swipe of
                Just (Start state) -> Just <| Swipe.Swiping
                    { x0 = state.x
                    , y0 = state.y
                    , x1 = update.x
                    , y1 = update.y
                    , id = state.id
                    , t0 = state.t0
                    , direction = Maybe.withDefault Right <| dir state.x state.y
                    }
                Just (Swipe.Swiping state) -> Just <| Swipe.Swiping
                    { x0 = state.x0
                    , y0 = state.y0
                    , x1 = update.x
                    , y1 = update.y
                    , id = state.id
                    , t0 = state.t0
                    , direction = Maybe.withDefault state.direction <| dir state.x0 state.y0
                    }
                _ -> Just <| Start update
            TouchEnd -> case swipe of
                Just (Start state) -> Just <| End
                    { x0 = state.x
                    , y0 = state.y
                    , x1 = update.x
                    , y1 = update.y
                    , id = state.id
                    , t0 = state.t0
                    , direction = Maybe.withDefault Right <| dir state.x state.y
                    }
                Just (Swipe.Swiping state) -> Just <| End
                    { x0 = state.x0
                    , y0 = state.y0
                    , x1 = update.x
                    , y1 = update.y
                    , id = state.id
                    , t0 = state.t0
                    , direction = Maybe.withDefault state.direction <| dir state.x0 state.y0
                    }
                _ -> Nothing

direction : Float -> Float -> Maybe Direction
direction dx dy =
    if abs dx > abs dy then
        if dx > 0 then
            Just Right
        else if dx < 0 then
            Just Left
        else
            Nothing
    else
        if dy > 0 then
            Just Down
        else if dy < 0 then
            Just Up
        else
            Nothing

type alias SwipeUpdate =
    { id : Int
    , x : Float
    , y : Float
    , t0 : Float
    }

type TouchState = TouchStart | TouchMove | TouchEnd

touch : Json.Decoder SwipeUpdate
touch = Json.object2 (\t0 touch -> {id = touch.id, x = touch.x, y = touch.y, t0 = toFloat t0})
    ("timeStamp" := Json.int)
    ("changedTouches" := Json.object1 (\x -> x)
        ("0" := changedTouch))

changedTouch = Json.object3 (\id x y -> {id = id, x = x, y = y})
    ("identifier" := Json.int)
    ("clientX" := Json.float)
    ("clientY" := Json.float)
