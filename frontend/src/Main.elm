module Main exposing (main)

import Array exposing (Array)
import Browser
import Browser.Navigation as Nav
import Common exposing (Member, groupOverviewApiResponseDecoder, httpErrorToString, logToConsole)
import GroupOverview
import Home
import Html exposing (Html, div, text)
import Html.Attributes exposing (class, id, name)
import Http
import Json.Encode as Encode
import NewExpense exposing (Tab(..))
import NewGroup exposing (Status(..))
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, string)


encodeMsgPage : Msg -> Page -> String
encodeMsgPage msg page =
    Encode.encode 2 <|
        Encode.object
            [ ( "page", Encode.string (pageToString page) )
            , ( "msg", Encode.string (msgToString msg) )
            ]


appName : String
appName =
    "Ledger"


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


type Page
    = Home
    | GroupOverview GroupOverview.Model
    | NewGroup NewGroup.Model
    | NewExpense NewExpense.Model
    | NotFound
    | Error


pageToString : Page -> String
pageToString page =
    case page of
        Home ->
            "Home"

        GroupOverview _ ->
            "GroupOverview"

        NewGroup _ ->
            "NewGroup"

        NewExpense _ ->
            "NewExpense"

        NotFound ->
            "NotFound"

        Error ->
            "Error"


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , page : Page
    }


type Msg
    = NoOp
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GroupOverviewMsg GroupOverview.Msg
    | NewGroupMsg NewGroup.Msg
    | NewExpenseMsg NewExpense.Msg
    | HomeMsg Home.Msg


msgToString : Msg -> String
msgToString msg =
    case msg of
        NoOp ->
            "NoOp"

        LinkClicked urlRequest ->
            let
                link =
                    case urlRequest of
                        Browser.Internal url ->
                            "Internal " ++ Url.toString url

                        Browser.External urlStr ->
                            "External " ++ urlStr
            in
            "LinkClicked " ++ link

        UrlChanged url ->
            "UrlChanged " ++ Url.toString url

        GroupOverviewMsg groupOverviewMsg ->
            "GroupOverviewMsg: " ++ GroupOverview.msgToString groupOverviewMsg

        NewGroupMsg newGroupMsg ->
            "NewGroupMsg: " ++ NewGroup.msgToString newGroupMsg

        NewExpenseMsg newExpenseMsg ->
            "NewExpenseMsg: " ++ NewExpense.msgToString newExpenseMsg

        HomeMsg homeMsg ->
            "HomeMsg: " ++ Home.msgToString homeMsg


pageParser : Parser (( Page, Cmd Msg ) -> a) a
pageParser =
    Parser.s "app"
        </> Parser.oneOf
                [ Parser.map ( Home, Cmd.none ) Parser.top
                , Parser.map ( NewGroup <| NewGroup.Model FillingForm "" "" [] "", Cmd.none ) (Parser.s "new-group")
                , Parser.map
                    (\id ->
                        ( GroupOverview <| GroupOverview.Model GroupOverview.Loading (Common.Group "" "" "" <| Array.fromList []) []
                        , Http.get
                            { url = "/group/" ++ id
                            , expect = Http.expectJson (GroupOverviewMsg << GroupOverview.GotGroupOverviewApiResponse) groupOverviewApiResponseDecoder
                            }
                        )
                    )
                    (Parser.string </> Parser.s "group-overview")
                , Parser.map
                    (\id ->
                        ( NewExpense <| NewExpense.Model NewExpense.Loading NewExpense.MoneyGiven id "" (Array.fromList []) -1 -1 0 "" ""
                        , Http.get
                            { url = "/group/" ++ id
                            , expect = Http.expectJson (NewExpenseMsg << NewExpense.GotGroupOverviewApiResponse) groupOverviewApiResponseDecoder
                            }
                        )
                    )
                    (Parser.string </> Parser.s "new-expense")
                ]


urlToPageCmd : Url -> ( Page, Cmd Msg )
urlToPageCmd url =
    Parser.parse pageParser url
        |> Maybe.withDefault ( NotFound, Cmd.none )


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        ( page, cmd ) =
            urlToPageCmd url
    in
    ( Model key url page, cmd )


groupIdParser : Parser (String -> a) a
groupIdParser =
    Parser.s "app"
        </> string
        </> Parser.oneOf
                [ Parser.s "group-overview"
                , Parser.s "new-expense"
                ]


urlToGroupId : Url -> Maybe String
urlToGroupId url =
    Parser.parse groupIdParser url


showErrorPage : Msg -> Model -> ( Model, Cmd Msg )
showErrorPage msg model =
    ( { model | page = Error }, logToConsole <| "Error: " ++ encodeMsgPage msg model.page )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChanged url ->
            let
                ( page, cmd ) =
                    urlToPageCmd url
            in
            ( { model | url = url, page = page }, cmd )

        _ ->
            case model.page of
                Home ->
                    updateHome msg model

                GroupOverview groupOverviewModel ->
                    updateGroupOverview msg model groupOverviewModel

                NewGroup newGroupModel ->
                    updateNewGroup msg model newGroupModel

                NewExpense newExpenseModel ->
                    updateNewExpense msg model newExpenseModel

                NotFound ->
                    ( model, Cmd.none )

                Error ->
                    ( model, Cmd.none )


updateHome : Msg -> Model -> ( Model, Cmd Msg )
updateHome msg model =
    case msg of
        HomeMsg homeMsg ->
            case homeMsg of
                Home.ClickedNewGroup ->
                    ( model, Nav.pushUrl model.key "/app/new-group" )

        _ ->
            showErrorPage msg model


updateGroupOverview : Msg -> Model -> GroupOverview.Model -> ( Model, Cmd Msg )
updateGroupOverview msg model groupOverviewModel =
    case msg of
        GroupOverviewMsg groupOverviewMsg ->
            case groupOverviewMsg of
                GroupOverview.ClickedNewExpense ->
                    case urlToGroupId model.url of
                        Nothing ->
                            ( { model | page = Error }, logToConsole <| "Error: Unable to parse groupId from url: " ++ model.url.path )

                        Just groupId ->
                            ( model, Nav.pushUrl model.key <| "/app/" ++ groupId ++ "/new-expense" )

                _ ->
                    let
                        ( updatedGroupOverviewModel, groupOverviewCmd ) =
                            GroupOverview.update groupOverviewMsg groupOverviewModel
                    in
                    ( { model | page = GroupOverview updatedGroupOverviewModel }, Cmd.map GroupOverviewMsg groupOverviewCmd )

        _ ->
            showErrorPage msg model


updateNewGroup : Msg -> Model -> NewGroup.Model -> ( Model, Cmd Msg )
updateNewGroup msg model newGroupModel =
    case msg of
        NewGroupMsg newGroupMsg ->
            case newGroupMsg of
                NewGroup.GotCreateGroupResponse (Err error) ->
                    ( { model | page = Error }, logToConsole <| "Error: " ++ httpErrorToString error )

                NewGroup.GotCreateGroupResponse (Ok response) ->
                    ( model, Nav.pushUrl model.key <| "/app/" ++ response.groupId ++ "/group-overview" )

                _ ->
                    let
                        ( updatedNewGroupModel, newGroupCmd ) =
                            NewGroup.update newGroupMsg newGroupModel
                    in
                    ( { model | page = NewGroup updatedNewGroupModel }, Cmd.map NewGroupMsg newGroupCmd )

        _ ->
            showErrorPage msg model


updateNewExpense : Msg -> Model -> NewExpense.Model -> ( Model, Cmd Msg )
updateNewExpense msg model newExpenseModel =
    case msg of
        NewExpenseMsg newExpenseMsg ->
            case newExpenseMsg of
                NewExpense.ClickedCancelBtn ->
                    case urlToGroupId model.url of
                        Nothing ->
                            ( { model | page = Error }, logToConsole <| "Error: Unable to parse groupId from url: " ++ model.url.path )

                        Just groupId ->
                            ( model, Nav.pushUrl model.key <| "/app/" ++ groupId ++ "/group-overview" )

                NewExpense.GotCreateExpenseResponse (Err error) ->
                    ( { model | page = Error }, logToConsole <| "Error: " ++ httpErrorToString error )

                NewExpense.GotCreateExpenseResponse (Ok _) ->
                    case urlToGroupId model.url of
                        Nothing ->
                            ( { model | page = Error }, logToConsole <| "Error: Unable to parse groupId from url: " ++ model.url.path )

                        Just groupId ->
                            ( model, Nav.pushUrl model.key <| "/app/" ++ groupId ++ "/group-overview" )

                _ ->
                    let
                        ( updatedNewExpenseModel, newExpenseCmd ) =
                            NewExpense.update newExpenseMsg newExpenseModel
                    in
                    ( { model | page = NewExpense updatedNewExpenseModel }, Cmd.map NewExpenseMsg newExpenseCmd )

        _ ->
            showErrorPage msg model


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


view : Model -> Browser.Document Msg
view model =
    { title = appName
    , body =
        case model.page of
            Home ->
                [ Home.view () |> Html.map HomeMsg ]

            GroupOverview groupOverviewModel ->
                [ GroupOverview.view groupOverviewModel |> Html.map GroupOverviewMsg ]

            NewGroup newGroupModel ->
                [ NewGroup.view newGroupModel |> Html.map NewGroupMsg ]

            NewExpense newExpenseModel ->
                [ NewExpense.view newExpenseModel |> Html.map NewExpenseMsg ]

            NotFound ->
                [ div [ id "root", class "p-3" ]
                    [ text "Not Found" ]
                ]

            Error ->
                [ div [ id "root", class "p-3" ]
                    [ text "Error" ]
                ]
    }
