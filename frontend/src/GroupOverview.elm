module GroupOverview exposing (Model(..), Msg(..), msgToString, update, view)

import Array exposing (Array)
import Common exposing (Group, GroupOverviewApiResponse, Member, Tr, httpErrorToString, logToConsole)
import Html exposing (Html, button, div, h3, h4, li, span, text, ul)
import Html.Attributes exposing (class, id, type_)
import Html.Events exposing (onClick)
import Http


type alias GroupInfo =
    { group : Group, trs : List Tr }


type Model
    = Loading String
    | Loaded GroupInfo
    | Error


type Msg
    = ClickedNewExpense
    | GotServerResponse (Result Http.Error GroupOverviewApiResponse)


msgToString : Msg -> String
msgToString msg =
    case msg of
        ClickedNewExpense ->
            "ClickedNewExpense"

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
    case msg of
        GotServerResponse (Err error) ->
            ( Error, logToConsole <| "Error: " ++ httpErrorToString error )

        GotServerResponse (Ok response) ->
            let
                groupInfo =
                    let
                        board =
                            response.groupBoard
                    in
                    { group =
                        { id = board.groupId
                        , name = board.name
                        , description = board.description
                        , members = Array.fromList board.members
                        }
                    , trs = []
                    }
            in
            ( Loaded groupInfo, Cmd.none )

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
    case model of
        Loading groupId ->
            [ text <| "Loading " ++ groupId ]

        Loaded groupInfo ->
            [ h3 [ class "text-center" ] [ text groupInfo.group.name ]
            , div [ class "d-flex align-items-center justify-content-between" ]
                [ h4 [] [ text "Expenses" ]
                , button
                    [ type_ "button"
                    , class "btn btn-primary btn-sm"
                    , onClick ClickedNewExpense
                    ]
                    [ text "New Expense" ]
                ]
            , if List.length groupInfo.trs == 0 then
                span [] [ text "No expenses yet" ]

              else
                ul [ class "list-group list-group-flush" ]
                    (List.map
                        (mapTr groupInfo.group.members)
                        groupInfo.trs
                    )
            ]

        Error ->
            [ text "Error" ]


view : Model -> Html Msg
view model =
    div [ id "root", class "p-3" ]
        [ card "Group overview" <| groupOverviewContent model ]
