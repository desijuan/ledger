module GroupOverview exposing (Model, Msg(..), Status(..), msgToString, update, view)

import Array exposing (Array)
import Common exposing (Group, GroupOverviewApiResponse, Member, Tr, httpErrorToString, logToConsole)
import Html exposing (Html, button, div, h3, h4, li, span, text, ul)
import Html.Attributes exposing (class, id, type_)
import Html.Events exposing (onClick)
import Http


type Status
    = Loading
    | Loaded
    | Error


type alias Model =
    { status : Status
    , group : Group
    , trs : List Tr
    }


type Msg
    = ClickedNewExpense
    | GotGroupOverviewApiResponse (Result Http.Error GroupOverviewApiResponse)


msgToString : Msg -> String
msgToString msg =
    case msg of
        ClickedNewExpense ->
            "ClickedNewExpense"

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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotGroupOverviewApiResponse (Err error) ->
            ( { model | status = Error }, logToConsole <| "Error: " ++ httpErrorToString error )

        GotGroupOverviewApiResponse (Ok response) ->
            let
                newModel =
                    let
                        board =
                            response.groupBoard
                    in
                    { status = Loaded
                    , group =
                        { id = board.groupId
                        , name = board.name
                        , description = board.description
                        , members = Array.fromList board.members
                        }
                    , trs = []
                    }
            in
            ( newModel, Cmd.none )

        ClickedNewExpense ->
            ( model, Cmd.none )


card : String -> List (Html Msg) -> Html Msg
card header body =
    div [ class "card mx-auto shadow-sm" ]
        [ div [ class "card-header" ]
            [ text header ]
        , div [ class "card-body" ]
            body
        ]


mapTr : Array Member -> Tr -> Html Msg
mapTr members tr =
    li [ class "list-group-item" ]
        [ text <|
            let
                from =
                    case Array.get tr.from_id members of
                        Nothing ->
                            "--"

                        Just member ->
                            member.name

                to =
                    case Array.get tr.to_id members of
                        Nothing ->
                            "--"

                        Just member ->
                            member.name
            in
            from ++ " gave " ++ String.fromInt tr.amount ++ " to " ++ to ++ " for " ++ tr.description ++ "."
        ]


groupOverviewContent : Model -> List (Html Msg)
groupOverviewContent model =
    case model.status of
        Error ->
            [ text "Error" ]

        Loading ->
            [ text "Loading... " ]

        Loaded ->
            [ h3 [ class "text-center" ] [ text model.group.name ]
            , div [ class "d-flex align-items-center justify-content-between" ]
                [ h4 [] [ text "Expenses" ]
                , button
                    [ type_ "button"
                    , class "btn btn-primary btn-sm"
                    , onClick ClickedNewExpense
                    ]
                    [ text "New Expense" ]
                ]
            , if List.length model.trs == 0 then
                span [] [ text "No expenses yet" ]

              else
                ul [ class "list-group list-group-flush" ]
                    (List.map
                        (mapTr model.group.members)
                        model.trs
                    )
            ]


view : Model -> Html Msg
view model =
    div [ id "root", class "p-3" ]
        [ card "Group overview" <| groupOverviewContent model ]
