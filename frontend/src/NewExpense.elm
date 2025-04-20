module NewExpense exposing (Model, Msg(..), Status(..), Tab(..), msgToString, update, view)

import Array exposing (Array)
import Browser
import Browser.Dom as Dom
import Common exposing (GroupOverviewApiResponse, Tr, httpErrorToString, logToConsole)
import Html exposing (Attribute, Html, button, div, h1, h3, h4, input, label, li, nav, option, p, select, span, text, ul)
import Html.Attributes exposing (checked, class, classList, for, id, name, selected, type_, value)
import Html.Events exposing (keyCode, on, onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Task


type Tab
    = Expense
    | MoneyGiven
    | Income


tabToString : Tab -> String
tabToString tab =
    case tab of
        Expense ->
            "Expense"

        MoneyGiven ->
            "MoneyGiven"

        Income ->
            "Income"


type alias TrInfo =
    { from_id : Int, to_id : Int, amount : Int, description : String, timestamp : String }


encodeTr : TrInfo -> Encode.Value
encodeTr tr =
    Encode.object
        [ ( "from_id", Encode.int tr.from_id )
        , ( "to_id", Encode.int tr.to_id )
        , ( "amount", Encode.int tr.amount )
        , ( "description", Encode.string tr.description )
        ]


type alias CreateExpenseResponse =
    { success : Bool
    , tr : Tr
    }


trDecoder : Decoder Tr
trDecoder =
    Decode.map6 Tr
        (Decode.field "tr_id" Decode.int)
        (Decode.field "from_id" Decode.int)
        (Decode.field "to_id" Decode.int)
        (Decode.field "amount" Decode.int)
        (Decode.field "description" Decode.string)
        (Decode.field "timestamp" Decode.string)


createExpenseResponseDecoder : Decoder CreateExpenseResponse
createExpenseResponseDecoder =
    Decode.map2 CreateExpenseResponse
        (Decode.field "success" Decode.bool)
        (Decode.field "tr" trDecoder)


type alias Member =
    { id : Int, name : String }


type Status
    = Loading
    | FillingForm
    | AwaitingServerResponse
    | Error String


type alias Model =
    { status : Status
    , activeTab : Tab
    , groupId : String
    , groupName : String
    , members : Array Member
    , from : Int
    , to : Int
    , amount : Int
    , description : String
    , timestamp : String
    }


type Msg
    = NoOp
    | UpdateAmount Int
    | UpdateDescription String
    | UpdateTimestamp String
    | ClickedTab Tab
    | SelectedFrom Int
    | SelectedTo Int
    | ClickedAddExpenseBtn
    | ClickedCancelBtn
    | GotGroupOverviewApiResponse (Result Http.Error GroupOverviewApiResponse)
    | GotCreateExpenseResponse (Result Http.Error CreateExpenseResponse)


msgToString : Msg -> String
msgToString msg =
    case msg of
        NoOp ->
            "NoOp"

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

        ClickedAddExpenseBtn ->
            "ClickedAddExpenseBtn"

        ClickedCancelBtn ->
            "ClickedCancelBtn"

        GotGroupOverviewApiResponse result ->
            let
                response =
                    case result of
                        Err error ->
                            httpErrorToString error

                        Ok _ ->
                            "Ok"
            in
            "GotGroupOverviewApiResponse " ++ response

        GotCreateExpenseResponse result ->
            let
                response =
                    case result of
                        Err error ->
                            httpErrorToString error

                        Ok _ ->
                            "Ok"
            in
            "GotCreateExpenseResponse" ++ response


focusElement : String -> Cmd Msg
focusElement htmlId =
    Task.attempt (\_ -> NoOp) (Dom.focus htmlId)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model.status of
        Loading ->
            case msg of
                GotGroupOverviewApiResponse (Err error) ->
                    ( { model | status = Error <| httpErrorToString error }, Cmd.none )

                GotGroupOverviewApiResponse (Ok response) ->
                    let
                        newModel =
                            let
                                board =
                                    response.groupBoard
                            in
                            { status = FillingForm
                            , activeTab = MoneyGiven
                            , groupId = board.groupId
                            , groupName = board.name
                            , members = Array.fromList board.members
                            , from = 1
                            , to = 2
                            , amount = 0
                            , description = ""
                            , timestamp = ""
                            }
                    in
                    ( newModel, Cmd.none )

                _ ->
                    ( { model | status = Error "TODO: fill" }, Cmd.none )

        FillingForm ->
            case msg of
                UpdateAmount value ->
                    ( { model | amount = value }, Cmd.none )

                UpdateDescription value ->
                    ( { model | description = value }, Cmd.none )

                UpdateTimestamp value ->
                    ( { model | timestamp = value }, Cmd.none )

                ClickedTab tab ->
                    ( { model | activeTab = tab }, Cmd.none )

                SelectedFrom memberId ->
                    ( { model
                        | from = memberId
                        , to =
                            if model.to == memberId then
                                -1

                            else
                                model.to
                      }
                    , Cmd.none
                    )

                SelectedTo memberId ->
                    ( { model | to = memberId }, Cmd.none )

                ClickedAddExpenseBtn ->
                    case model.activeTab of
                        Expense ->
                            ( { model | status = Error "TODO 1" }, Cmd.none )

                        MoneyGiven ->
                            if model.from <= 0 then
                                ( model, focusElement "expense-from" )

                            else if model.to <= 0 then
                                ( model, focusElement "expense-to" )

                            else if model.amount <= 0 then
                                ( model, focusElement "expense-amount" )

                            else if String.length model.timestamp == 0 then
                                ( model, focusElement "expense-date" )

                            else
                                let
                                    newTr =
                                        TrInfo model.from model.to model.amount model.description model.timestamp
                                in
                                ( { model | status = AwaitingServerResponse }
                                , Http.post
                                    { url = "/group/" ++ model.groupId ++ "/new-expense"
                                    , body = Http.jsonBody (encodeTr newTr)
                                    , expect = Http.expectJson GotCreateExpenseResponse createExpenseResponseDecoder
                                    }
                                )

                        Income ->
                            ( { model | status = Error "TODO 2" }, Cmd.none )

                NoOp ->
                    ( model, Cmd.none )

                _ ->
                    ( { model | status = Error ("TODO 3 " ++ msgToString msg) }, Cmd.none )

        AwaitingServerResponse ->
            ( model, Cmd.none )

        Error _ ->
            ( model, Cmd.none )


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


newExpenseForm : Model -> List (Html Msg)
newExpenseForm model =
    case model.status of
        Error errorMsg ->
            [ text <| "Error: " ++ errorMsg ]

        AwaitingServerResponse ->
            [ text "Loading... " ]

        Loading ->
            [ text "Loading... " ]

        FillingForm ->
            case model.activeTab of
                Income ->
                    [ text "Not implemented yet" ]

                Expense ->
                    [ text "Not implemented yet" ]

                MoneyGiven ->
                    let
                        membersList =
                            case List.tail <| Array.toList model.members of
                                Nothing ->
                                    []

                                Just list ->
                                    list
                    in
                    [ div [ class "row g-3 align-items-center" ]
                        [ div [ class "col-auto" ]
                            [ select [ id "expense-from", class "form-select", onInput (SelectedFrom << stringToInt) ]
                                (List.map (mapOption model.from) membersList)
                            ]
                        , div [ class "col" ]
                            [ p [ class "col-form-label" ] [ text "gave money." ]
                            ]
                        ]
                    , div [ class "form-group mt-3" ]
                        (label [ id "expense-to", class "form-label", for "to" ] [ text "To whom?" ]
                            :: List.map (mapRadio model.to) (List.filter (\member -> member.id /= model.from) membersList)
                        )
                    , div [ class "form-group mt-3" ]
                        [ label [ id "expense-amount", class "form-label", for "amount" ] [ text "How much?" ]
                        , div [ class "input-group" ]
                            [ span [ class "input-group-text" ] [ text "$" ]
                            , input
                                [ type_ "number"
                                , class "form-control"
                                , value <| String.fromInt model.amount
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
                            , value model.description
                            , onInput UpdateDescription
                            ]
                            []
                        ]
                    , div [ class "form-group mt-3" ]
                        [ label [ id "expense-date", class "form-label", for "timestamp" ] [ text "When?" ]
                        , input
                            [ type_ "date"
                            , class "form-control"
                            , value model.timestamp
                            , onInput UpdateTimestamp
                            ]
                            []
                        ]
                    , div [ class "d-grid gap-2 mx-auto mt-3" ]
                        [ button [ type_ "button", class "btn btn-primary", onClick ClickedAddExpenseBtn ] [ text "Add expense" ]
                        , button [ type_ "button", class "btn btn-secondary", onClick ClickedCancelBtn ] [ text "Cancel" ]
                        ]
                    ]


newExpense : Model -> List (Html Msg)
newExpense model =
    newExpenseTabs model.activeTab :: newExpenseForm model


view : Model -> Html Msg
view model =
    div [ id "root", class "p-3" ]
        [ card "New Expense" <| newExpense model
        ]
