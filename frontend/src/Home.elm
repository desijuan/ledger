module Home exposing (Msg(..), msgToString, view)

import Browser
import Html exposing (Html, button, div, h1, h3, h4, input, label, li, nav, option, p, select, span, text, ul)
import Html.Attributes exposing (checked, class, for, id, name, type_, value)
import Html.Events exposing (onClick)


type Msg
    = ClickedNewGroup


msgToString : Msg -> String
msgToString msg =
    case msg of
        ClickedNewGroup ->
            "ClickedNewGroup"


simpleCard : List (Html Msg) -> Html Msg
simpleCard body =
    div [ class "card mx-auto shadow-sm" ]
        [ div [ class "card-body text-center" ]
            body
        ]


home : List (Html Msg)
home =
    [ h1 [] [ text "Ledger" ]
    , button
        [ type_ "button"
        , class "btn btn-primary btn-lg mt-3 mb-1"
        , onClick ClickedNewGroup
        ]
        [ text "New group" ]
    ]


view : () -> Html Msg
view _ =
    div [ id "root", class "p-3" ]
        [ simpleCard home ]
