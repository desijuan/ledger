module NewGroup exposing (Model, Msg(..), Status(..), msgToString, update, view)

import Browser
import Browser.Dom as Dom
import Common exposing (httpErrorToString)
import Html exposing (Attribute, Html, button, div, h4, input, label, li, option, text, ul)
import Html.Attributes exposing (class, for, id, type_, value)
import Html.Events exposing (keyCode, on, onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Task


groupNameId =
    "group-name"


groupDescriptionId =
    "group-description"


addMemberId =
    "add-member"


type Status
    = FillingForm
    | AwaitingServerResponse


type alias Model =
    { status : Status
    , groupName : String
    , groupDescription : String
    , groupMembers : List String
    , newMember : String
    }


type Msg
    = NoOp
    | UpdateGroupName String
    | UpdateGroupDescription String
    | UpdateNewMember String
    | PressedEnterGroupName
    | PressedEnterGroupDescription
    | PressedEnterAddMember
    | ClickedAddMember
    | ClickedClearMembers
    | ClickedDone
    | GotCreateGroupResponse (Result Http.Error CreateGroupResponse)


msgToString : Msg -> String
msgToString msg =
    case msg of
        NoOp ->
            "NoOp"

        UpdateGroupName str ->
            "UpdateGroupName " ++ str

        UpdateGroupDescription str ->
            "UpdateGroupDescription " ++ str

        UpdateNewMember str ->
            "UpdateNewMember " ++ str

        PressedEnterGroupName ->
            "PressedEnterGroupName"

        PressedEnterGroupDescription ->
            "PressedEnterGroupDescription"

        PressedEnterAddMember ->
            "PressedEnterAddMember"

        ClickedAddMember ->
            "ClickedAddMember"

        ClickedClearMembers ->
            "ClickedClearMembers"

        ClickedDone ->
            "ClickedDone"

        GotCreateGroupResponse result ->
            let
                response =
                    case result of
                        Err error ->
                            httpErrorToString error

                        Ok _ ->
                            "Ok"
            in
            "GotCreateGroupResponse " ++ response


focusElement : String -> Cmd Msg
focusElement htmlId =
    Task.attempt (\_ -> NoOp) (Dom.focus htmlId)


type alias Group =
    { name : String
    , description : String
    , members : List String
    }


type alias CreateGroupResponse =
    { success : Bool
    , groupId : String
    }


encodeGroup : Group -> Encode.Value
encodeGroup group =
    Encode.object
        [ ( "name", Encode.string group.name )
        , ( "description", Encode.string group.description )
        , ( "members", Encode.list Encode.string group.members )
        ]


createGroupResponseDecoder : Decoder CreateGroupResponse
createGroupResponseDecoder =
    Decode.map2 CreateGroupResponse
        (Decode.field "success" Decode.bool)
        (Decode.field "group_id" Decode.string)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        UpdateGroupName value ->
            ( { model | groupName = value }, Cmd.none )

        UpdateGroupDescription value ->
            ( { model | groupDescription = value }, Cmd.none )

        UpdateNewMember value ->
            ( { model | newMember = value }, Cmd.none )

        PressedEnterGroupName ->
            if String.length model.groupName == 0 then
                ( model, Cmd.none )

            else
                ( model, focusElement groupDescriptionId )

        PressedEnterGroupDescription ->
            if String.length model.groupDescription == 0 then
                ( model, Cmd.none )

            else
                ( model, focusElement addMemberId )

        PressedEnterAddMember ->
            if
                (String.length model.newMember == 0)
                    || List.member model.newMember model.groupMembers
            then
                ( model, Cmd.none )

            else
                ( { model | newMember = "", groupMembers = model.groupMembers ++ [ model.newMember ] }, Cmd.none )

        ClickedAddMember ->
            if
                (String.length model.newMember == 0)
                    || List.member model.newMember model.groupMembers
            then
                ( model, focusElement addMemberId )

            else
                ( { model | newMember = "", groupMembers = model.newMember :: model.groupMembers }, focusElement addMemberId )

        ClickedClearMembers ->
            ( { model | newMember = "", groupMembers = [] }, focusElement addMemberId )

        ClickedDone ->
            if String.length model.groupName == 0 then
                ( model, focusElement groupNameId )

            else if String.length model.groupDescription == 0 then
                ( model, focusElement groupDescriptionId )

            else if List.length model.groupMembers < 2 then
                ( model, focusElement addMemberId )

            else
                let
                    newGroup =
                        Group model.groupName model.groupDescription model.groupMembers
                in
                ( { model | status = AwaitingServerResponse }
                , Http.post
                    { url = "/new-group"
                    , body = Http.jsonBody (encodeGroup newGroup)
                    , expect = Http.expectJson GotCreateGroupResponse createGroupResponseDecoder
                    }
                )

        GotCreateGroupResponse _ ->
            ( model, Cmd.none )



-- Taken from:
-- https://github.com/evancz/elm-todomvc/blob/166e5f2afc704629ee6d03de00deac892dfaeed0/Todo.elm#L237-L246


onEnter : Msg -> Attribute Msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Decode.succeed msg

            else
                Decode.fail "not ENTER"
    in
    on "keydown" (Decode.andThen isEnter keyCode)


mapMember : String -> Html Msg
mapMember memberName =
    li [ class "list-group-item" ] [ text memberName ]


card : String -> List (Html Msg) -> Html Msg
card header body =
    div [ class "card mx-auto shadow-sm" ]
        [ div [ class "card-header" ]
            [ text header ]
        , div [ class "card-body" ]
            body
        ]


newGroupForm : Model -> List (Html Msg)
newGroupForm model =
    case model.status of
        FillingForm ->
            [ div []
                [ label [ class "form-label", for groupNameId ] [ text "Group name:" ]
                , input
                    [ type_ "text"
                    , id groupNameId
                    , class "form-control"
                    , value model.groupName
                    , onInput UpdateGroupName
                    , onEnter PressedEnterGroupName
                    ]
                    []
                ]
            , div [ class "mt-3" ]
                [ label [ class "form-label", for groupDescriptionId ] [ text "Description:" ]
                , input
                    [ type_ "text"
                    , id groupDescriptionId
                    , class "form-control"
                    , value model.groupDescription
                    , onInput UpdateGroupDescription
                    , onEnter PressedEnterGroupDescription
                    ]
                    []
                ]
            , div [ class "mt-3" ]
                [ label [ class "form-label", for addMemberId ] [ text "Add participant:" ]
                , div [ class "input-group" ]
                    [ input
                        [ type_ "text"
                        , id addMemberId
                        , class "form-control"
                        , value model.newMember
                        , onInput UpdateNewMember
                        , onEnter PressedEnterAddMember
                        ]
                        []
                    , button
                        [ type_ "button"
                        , class "btn btn-primary"
                        , onClick ClickedAddMember
                        ]
                        [ text "Add" ]
                    ]
                ]
            , div []
                [ div [ class "d-flex align-items-center justify-content-between mt-3" ]
                    [ h4 [] [ text ("Members (" ++ String.fromInt (List.length model.groupMembers) ++ ")") ]
                    , button
                        [ type_ "button"
                        , class "btn btn-primary btn-sm"
                        , onClick ClickedClearMembers
                        ]
                        [ text "Clear" ]
                    ]
                , ul [] (List.map mapMember model.groupMembers)
                ]
            , div [ class "d-grid gap-2 mx-auto" ]
                [ button
                    [ type_ "button"
                    , class "btn btn-primary"
                    , onClick ClickedDone
                    ]
                    [ text "Done!" ]
                ]
            ]

        AwaitingServerResponse ->
            [ text "Loading..." ]


view : Model -> Html Msg
view model =
    div [ id "root", class "p-3" ]
        [ card "New Group" <| newGroupForm model
        ]
