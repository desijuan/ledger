module NewExpense exposing (Model(..), Msg(..), Tab(..), msgToString, update, view)

import Array exposing (Array)
import Browser
import Browser.Dom as Dom
import Common exposing (GroupOverviewApiResponse, httpErrorToString, logToConsole)
import Html exposing (Attribute, Html, button, div, h1, h3, h4, input, label, li, nav, option, p, select, span, text, ul)
import Html.Attributes exposing (checked, class, classList, for, id, name, selected, type_, value)
import Html.Events exposing (keyCode, on, onClick, onInput)
import Http
import Task


type Tab
    = Income
    | Expense
    | MoneyGiven


tabToString : Tab -> String
tabToString tab =
    case tab of
        Income ->
            "Income"

        Expense ->
            "Expense"

        MoneyGiven ->
            "MoneyGiven"


type alias Member =
    { id : Int, name : String }


type alias PageModel =
    { activeTab : Tab
    , groupName : String
    , members : Array Member
    , from : Int
    , to : Int
    , amount : Int
    , description : String
    , timestamp : String
    }


type Model
    = Loading String
    | Loaded PageModel
    | Error


type Msg
    = UpdateAmount Int
    | UpdateDescription String
    | UpdateTimestamp String
    | ClickedTab Tab
    | SelectedFrom Int
    | SelectedTo Int
    | GotServerResponse (Result Http.Error GroupOverviewApiResponse)


msgToString : Msg -> String
msgToString msg =
    case msg of
        UpdateAmount n ->
            "UpdateAmount " ++ String.fromInt n

        UpdateDescription str ->
            "UpdateDescription " ++ str

        UpdateTimestamp str ->
            "UpdateTimestamp " ++ str

        ClickedTab tab ->
            "ClickedTab " ++ tabToString tab

        SelectedFrom n ->
            "SelectedFrom " ++ String.fromInt n

        SelectedTo n ->
            "SelectedTo " ++ String.fromInt n

        GotServerResponse result ->
            let
                response =
                    case result of
                        Err error ->
                            httpErrorToString error

                        Ok _ ->
                            "Ok"
            in
            "GotServerResponse " ++ response


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        Loading _ ->
            case msg of
                GotServerResponse (Err error) ->
                    ( Error, logToConsole <| "Error: " ++ httpErrorToString error )

                GotServerResponse (Ok response) ->
                    let
                        pageModel =
                            let
                                board =
                                    response.groupBoard
                            in
                            { activeTab = MoneyGiven
                            , groupName = board.name
                            , members = Array.fromList board.members
                            , from = 1
                            , to = 2
                            , amount = 0
                            , description = ""
                            , timestamp = ""
                            }
                    in
                    ( Loaded pageModel, Cmd.none )

                _ ->
                    ( Error, Cmd.none )

        Loaded pageModel ->
            case msg of
                UpdateAmount value ->
                    ( Loaded { pageModel | amount = value }, Cmd.none )

                UpdateDescription value ->
                    ( Loaded { pageModel | description = value }, Cmd.none )

                UpdateTimestamp value ->
                    ( Loaded { pageModel | timestamp = value }, Cmd.none )

                ClickedTab tab ->
                    ( Loaded { pageModel | activeTab = tab }, Cmd.none )

                SelectedFrom memberId ->
                    ( Loaded
                        { pageModel
                            | from = memberId
                            , to =
                                if pageModel.to == memberId then
                                    -1

                                else
                                    pageModel.to
                        }
                    , Cmd.none
                    )

                SelectedTo memberId ->
                    ( Loaded { pageModel | to = memberId }, Cmd.none )

                _ ->
                    ( Error, Cmd.none )

        Error ->
            ( Error, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


card : String -> List (Html Msg) -> Html Msg
card header body =
    div [ class "card mx-auto shadow-sm" ]
        [ div [ class "card-header" ]
            [ text header ]
        , div [ class "card-body" ]
            body
        ]


newExpenseTabs : Tab -> Html Msg
newExpenseTabs activeTab =
    nav [ class "nav nav-tabs flex-row flew-nowrap justify-content-between mb-3" ]
        [ tabBtn activeTab Expense "Expense"
        , tabBtn activeTab MoneyGiven "Money Given"
        , tabBtn activeTab Income "Income"
        ]


tabBtn : Tab -> Tab -> String -> Html Msg
tabBtn activeTab tab tabName =
    button [ class "nav-link flex-fill", classList [ ( "active", activeTab == tab ) ], onClick <| ClickedTab tab ]
        [ text tabName ]


mapOption : Int -> Member -> Html Msg
mapOption selectedId member =
    option [ value <| String.fromInt member.id, selected (selectedId == member.id) ] [ text member.name ]


mapRadio : Int -> Member -> Html Msg
mapRadio selectedId member =
    div [ class "form-check" ]
        [ input
            [ type_ "radio"
            , id ("radio-" ++ String.fromInt member.id)
            , class "form-check-input"
            , value <| String.fromInt member.id
            , onInput (SelectedTo << stringToInt)
            , checked (selectedId == member.id)
            ]
            []
        , label [ class "form-check-label", for ("radio-" ++ String.fromInt member.id) ] [ text member.name ]
        ]


stringToInt : String -> Int
stringToInt str =
    case String.toInt str of
        Nothing ->
            -1

        Just n ->
            n


newExpenseForm : PageModel -> List (Html Msg)
newExpenseForm pageModel =
    case pageModel.activeTab of
        Income ->
            [ text "Not implemented yet" ]

        Expense ->
            [ text "Not implemented yet" ]

        MoneyGiven ->
            let
                membersList =
                    case List.tail <| Array.toList pageModel.members of
                        Nothing ->
                            []

                        Just list ->
                            list
            in
            [ div [ class "row g-3 align-items-center" ]
                [ div [ class "col-auto" ]
                    [ select [ class "form-select", onInput (SelectedFrom << stringToInt) ]
                        (List.map (mapOption pageModel.from) membersList)
                    ]
                , div [ class "col" ]
                    [ p [ class "col-form-label" ] [ text "gave money." ]
                    ]
                ]
            , div [ class "form-group mt-3" ]
                (label [ class "form-label", for "to" ] [ text "To whom?" ]
                    :: List.map (mapRadio pageModel.to) (List.filter (\member -> member.id /= pageModel.from) membersList)
                )
            , div [ class "form-group mt-3" ]
                [ label [ class "form-label", for "amount" ] [ text "How much?" ]
                , div [ class "input-group" ]
                    [ span [ class "input-group-text" ] [ text "$" ]
                    , input
                        [ type_ "number"
                        , class "form-control"
                        , value <| String.fromInt pageModel.amount
                        , onInput (UpdateAmount << stringToInt)
                        , Html.Attributes.min "0"
                        , name "amount"
                        ]
                        []
                    ]
                ]
            , div [ class "form-group mt-3" ]
                [ label [ class "form-label", for "description" ] [ text "What for?" ]
                , input
                    [ type_ "text"
                    , class "form-control"
                    , value pageModel.description
                    , onInput UpdateDescription
                    ]
                    []
                ]
            , div [ class "form-group mt-3" ]
                [ label [ class "form-label", for "timestamp" ] [ text "When?" ]
                , input
                    [ type_ "date"
                    , class "form-control"
                    , value pageModel.timestamp
                    , onInput UpdateTimestamp
                    ]
                    []
                ]
            ]


newExpense : Model -> List (Html Msg)
newExpense model =
    case model of
        Loading groupId ->
            [ text <| "Loading " ++ groupId ]

        Loaded pageModel ->
            newExpenseTabs pageModel.activeTab :: newExpenseForm pageModel

        Error ->
            [ text "Error" ]


view : Model -> Html Msg
view model =
    div [ id "root", class "p-3" ]
        [ card "New Expense" <| newExpense model
        ]
